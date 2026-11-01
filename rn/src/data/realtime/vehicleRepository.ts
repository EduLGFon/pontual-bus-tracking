// Vehicle repository: snapshot first, then read-only WebSocket stream,
// with watchdog resync and polling fallback. Stops cleanly on background.
// Mirrors app/lib/data/realtime/vehicle_repository.dart.
import { API_BASE_URL } from "../../core/config/env";
import { parseReports } from "../api/dto";
import { reportKindFromWire } from "../../domain/reporting/reportKind";

export interface ClientVehicle {
  id: number;
  lat: number;
  lng: number;
  heading: number | null;
  kmh: number;
  members: number;
  ageS: number;
  paceKmh: number | null;
  receivedAtMs: number | null;
}

export function vehicleFromRow(row: unknown[]): ClientVehicle | null {
  try {
    if (!Array.isArray(row) || row.length < 7) return null;
    const id = row[0];
    const lat = row[1];
    const lng = row[2];
    if (typeof id !== "number" || typeof lat !== "number" || typeof lng !== "number") return null;
    return {
      id,
      lat,
      lng,
      heading: typeof row[3] === "number" ? row[3] : null,
      kmh: typeof row[4] === "number" ? row[4] : 0,
      members: typeof row[5] === "number" ? row[5] : 0,
      ageS: typeof row[6] === "number" ? row[6] : 0,
      paceKmh: row.length > 7 && typeof row[7] === "number" ? row[7] : null,
      receivedAtMs: null,
    };
  } catch {
    return null;
  }
}

export function vehicleAgeAt(v: ClientVehicle, nowMs: number): number {
  if (v.receivedAtMs === null) return v.ageS;
  const elapsed = Math.floor((nowMs - v.receivedAtMs) / 1000);
  return v.ageS + (elapsed < 0 ? 0 : elapsed);
}

export interface ClientReport {
  kind: string;
  area: string | null;
  count: number;
  createdAgeS: number;
  updatedAgeS: number;
  expiresInS: number;
  receivedAtMs: number | null;
}

export type StreamStatus = "connecting" | "live" | "stale" | "offline";

export const staleAfterS = 45;
export const watchdogResyncS = 30;
export const pollFallbackAfterS = 15;
export const pollIntervalS = 10;
export const reconnectDelaysS = [5, 10, 20, 30];

export interface ClientSnapshot {
  vehicles: ClientVehicle[];
  reports: ClientReport[];
}

function stampVehicles(vs: ClientVehicle[], nowMs: number): ClientVehicle[] {
  return vs.map((v) => ({ ...v, receivedAtMs: nowMs }));
}

export class VehicleRepository {
  private fetchSnapshot: (lineId: number) => Promise<ClientSnapshot>;
  private lineId: number | null = null;
  private vehicles: ClientVehicle[] = [];
  private reports: ClientReport[] = [];
  private status: StreamStatus = "connecting";
  private lastSnapshotAtMs: number | null = null;
  private lastFrameAtMs: number | null = null;
  private ws: WebSocket | null = null;
  private watchdog: ReturnType<typeof setTimeout> | null = null;
  private poller: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempt = 0;
  private socketDownAtMs: number | null = null;
  private stopped = true;
  private resyncing = false;
  private listeners = new Set<() => void>();
  private clock: () => number;

  constructor(opts?: {
    fetchSnapshot?: (lineId: number) => Promise<ClientSnapshot>;
    clock?: () => number;
  }) {
    this.fetchSnapshot = opts?.fetchSnapshot ?? defaultFetchSnapshot;
    this.clock = opts?.clock ?? (() => Date.now());
  }

  get currentLine(): number | null {
    return this.lineId;
  }

  get currentVehicles(): ClientVehicle[] {
    const now = this.clock();
    return this.vehicles.map((v) => ({ ...v, ageS: vehicleAgeAt(v, now) }));
  }

  get currentReports(): ClientReport[] {
    return [...this.reports];
  }

  get streamStatus(): StreamStatus {
    return this.status;
  }

  onChange(cb: () => void): () => void {
    this.listeners.add(cb);
    return () => {
      this.listeners.delete(cb);
    };
  }

  private emit(): void {
    this.listeners.forEach((cb) => {
      try {
        cb();
      } catch {}
    });
  }

  async start(lineId: number): Promise<void> {
    await this.stop();
    this.stopped = false;
    this.lineId = lineId;
    this.reconnectAttempt = 0;
    this.status = "connecting";
    this.reports = [];
    await this.resync();
    if (this.stopped) return;
    this.connect();
    this.armWatchdog();
  }

  async refresh(): Promise<void> {
    await this.resync();
  }

  async stop(): Promise<void> {
    this.stopped = true;
    if (this.watchdog) clearTimeout(this.watchdog);
    if (this.poller) clearInterval(this.poller as unknown as number);
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.watchdog = null;
    this.poller = null;
    this.reconnectTimer = null;
    try {
      this.ws?.close();
    } catch {}
    this.ws = null;
    this.lineId = null;
    this.lastFrameAtMs = null;
  }

  evaluateAge(): void {
    if (this.lastSnapshotAtMs === null) {
      this.status = this.ws === null ? "offline" : "connecting";
      return;
    }
    const ageS = Math.floor((this.clock() - this.lastSnapshotAtMs) / 1000);
    this.status = ageS > staleAfterS ? "stale" : "live";
    this.emit();
  }

  private async resync(): Promise<void> {
    const line = this.lineId;
    if (line === null || this.stopped || this.resyncing) return;
    this.resyncing = true;
    try {
      const fetched = await this.fetchSnapshot(line);
      if (this.stopped || this.lineId !== line) return;
      const now = this.clock();
      this.vehicles = stampVehicles(fetched.vehicles, now);
      this.reports = fetched.reports.map((r) => ({ ...r, receivedAtMs: now }));
      this.lastSnapshotAtMs = now;
      this.lastFrameAtMs = now;
      this.evaluateAge();
    } catch {
    } finally {
      this.resyncing = false;
    }
  }

  private connect(): void {
    const line = this.lineId;
    if (line === null || this.stopped) return;
    const url = API_BASE_URL.replace(/^http/, "ws") + "/v1/stream";
    try {
      const ws = new WebSocket(url);
      this.ws = ws;
      this.socketDownAtMs = null;
      ws.onopen = () => {
        this.reconnectAttempt = 0;
        try {
          ws.send(JSON.stringify({ op: "sub", line }));
        } catch {}
      };
      ws.onmessage = (ev) => {
        try {
          const data = JSON.parse(String((ev as MessageEvent).data));
          if (data?.bye === "restart") {
            const delayMs = 1000 + Math.random() * 9000;
            try {
              ws.close();
            } catch {}
            this.scheduleReconnect(delayMs);
            return;
          }
          if (data == null || typeof data !== "object") return;
          this.lastFrameAtMs = this.clock();
          if (typeof data.t === "number" && Array.isArray(data.v)) {
            const now = this.clock();
            const vs: ClientVehicle[] = [];
            for (const row of data.v) {
              const v = vehicleFromRow(row as unknown[]);
              if (v) vs.push({ ...v, receivedAtMs: now });
            }
            this.vehicles = vs;
            const dtos = parseReports(data.r ?? []);
            this.reports = dtos.map((d) => ({
              kind: reportKindFromWire(d.kind),
              area: d.area ?? null,
              count: d.count,
              createdAgeS: d.created_age_s,
              updatedAgeS: d.updated_age_s,
              expiresInS: d.expires_in_s,
              receivedAtMs: now,
            }));
            this.lastSnapshotAtMs = now;
            this.evaluateAge();
          }
        } catch {}
      };
      ws.onclose = () => {
        if (this.ws === ws) this.ws = null;
        if (this.stopped) return;
        if (this.socketDownAtMs === null) this.socketDownAtMs = this.clock();
        this.armPoller();
        this.scheduleReconnect();
      };
      ws.onerror = () => {
        try {
          ws.close();
        } catch {}
      };
    } catch {
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect(delayMs?: number): void {
    if (this.stopped) return;
    const step = reconnectDelaysS[Math.min(this.reconnectAttempt, reconnectDelaysS.length - 1)];
    this.reconnectAttempt += 1;
    const base = delayMs ?? step * 1000;
    const jitter = Math.random() * 1000 - 500;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => {
      if (!this.stopped) this.connect();
    }, Math.max(500, base + jitter));
  }

  private armWatchdog(): void {
    if (this.watchdog) clearTimeout(this.watchdog);
    this.watchdog = setTimeout(() => {
      if (this.stopped) return;
      const now = this.clock();
      const lastFrame = this.lastFrameAtMs;
      if (lastFrame === null || now - lastFrame > watchdogResyncS * 1000) {
        void this.resync();
      }
      this.armWatchdog();
    }, watchdogResyncS * 1000);
  }

  private armPoller(): void {
    if (this.poller || this.stopped) return;
    this.poller = setInterval(() => {
      if (this.stopped) return;
      const downAt = this.socketDownAtMs;
      if (downAt === null) return;
      if (this.clock() - downAt < pollFallbackAfterS * 1000) return;
      if (this.ws !== null) return;
      void this.resync();
    }, pollIntervalS * 1000) as unknown as ReturnType<typeof setTimeout>;
  }
}

async function defaultFetchSnapshot(lineId: number): Promise<ClientSnapshot> {
  const res = await fetch(`${API_BASE_URL}/v1/lines/${lineId}/vehicles`);
  if (!res.ok) throw new Error(`snapshot ${res.status}`);
  const body = await res.json();
  const vs: ClientVehicle[] = [];
  for (const row of body?.v ?? []) {
    const v = vehicleFromRow(row as unknown[]);
    if (v) vs.push(v);
  }
  const dtos = parseReports(body?.r ?? []);
  return {
    vehicles: vs,
    reports: dtos.map((d) => ({
      kind: reportKindFromWire(d.kind),
      area: d.area ?? null,
      count: d.count,
      createdAgeS: d.created_age_s,
      updatedAgeS: d.updated_age_s,
      expiresInS: d.expires_in_s,
      receivedAtMs: null,
    })),
  };
}

export const vehicleRepository = new VehicleRepository();

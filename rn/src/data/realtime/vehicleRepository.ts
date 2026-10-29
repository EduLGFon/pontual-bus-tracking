// Vehicle repository (WebSocket + polling fallback).
// Mirrors app/lib/data/realtime/vehicle_repository.dart (simplified).
import { API_BASE_URL } from "../../core/config/env";
import { backoffMs } from "../../core/net/backoff";
import type { VehiclesSnapshot } from "../api/dto";

export type VehicleUpdate = { lineId: number; snapshot: VehiclesSnapshot };

export class VehicleRepository {
  private ws: WebSocket | null = null;
  private lineId: number | null = null;
  private attempt = 0;
  private listeners = new Set<(u: VehicleUpdate) => void>();
  private pollTimer: any = null;

  subscribe(lineId: number, cb: (u: VehicleUpdate) => void): () => void {
    this.listeners.add(cb);
    if (this.lineId !== lineId) {
      this.lineId = lineId;
      this.connect();
    }
    return () => {
      this.listeners.delete(cb);
      if (this.listeners.size === 0) this.disconnect();
    };
  }

  private connect() {
    if (this.lineId == null) return;
    const url = API_BASE_URL.replace(/^http/, "ws") + "/v1/stream";
    try {
      const ws = new WebSocket(url);
      this.ws = ws;
      ws.onopen = () => {
        this.attempt = 0;
        try {
          ws.send(JSON.stringify(this.lineId));
        } catch {}
      };
      ws.onmessage = (ev) => {
        try {
          const data = JSON.parse(String(ev.data));
          const snap: VehiclesSnapshot = {
            t: data.t,
            v: data.v,
            r: data.r ?? [],
          };
          const u: VehicleUpdate = { lineId: data.l ?? this.lineId!, snapshot: snap };
          this.listeners.forEach((cb) => cb(u));
        } catch {}
      };
      ws.onclose = () => {
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

  private scheduleReconnect() {
    const delay = backoffMs(this.attempt++);
    setTimeout(() => this.connect(), delay);
  }

  private disconnect() {
    try {
      this.ws?.close();
    } catch {}
    this.ws = null;
    this.lineId = null;
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.pollTimer = null;
  }
}

export const vehicleRepository = new VehicleRepository();

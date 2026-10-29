// BusApi. Mirrors app/lib/data/api/bus_api.dart.
import { API_BASE_URL } from "../../core/config/env";
import {
  NetworkFailure,
  ServerFailure,
} from "../../core/errors/failures";
import type {
  ArrivalsPayload,
  LiveLines,
  ReportDTO,
  TripInstruction,
  VehiclesSnapshot,
} from "./dto";
import {
  ArrivalsPayloadSchema,
  LiveLinesSchema,
  VehiclesSnapshotSchema,
  TripInstructionSchema,
} from "./dto";
import * as tokenStore from "../prefs/tokenStore";

const REQUEST_TIMEOUT_MS = 15000;

export type Result<T> = { ok: true; value: T } | { ok: false; failure: any };

function ok<T>(value: T): Result<T> {
  return { ok: true, value };
}
function err<T>(failure: any): Result<T> {
  return { ok: false, failure };
}

export type BaseUrlProvider = () => string;

export class BusApi {
  baseUrl: BaseUrlProvider;
  private cachedToken: string | null = null;
  private vehiclesEtags = new Map<number, string>();
  private vehiclesCache = new Map<number, VehiclesSnapshot>();

  constructor(baseUrl: BaseUrlProvider = () => API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async token(): Promise<string | null> {
    if (this.cachedToken) return this.cachedToken;
    const t = await tokenStore.readToken();
    this.cachedToken = t;
    return t;
  }

  private async ensureRegistered(force = false): Promise<Result<string>> {
    if (!force) {
      const cached = this.cachedToken ?? (await tokenStore.readToken());
      if (cached) {
        this.cachedToken = cached;
        return ok(cached);
      }
    }
    try {
      const res = await fetch(`${this.baseUrl()}/v1/devices`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: "{}",
      });
      const timeout = setTimeout(() => {}, REQUEST_TIMEOUT_MS);
      clearTimeout(timeout);
      if (res.status !== 201) {
        return err(new ServerFailure("register failed", "register"));
      }
      const body = (await res.json()) as any;
      const token = body?.token as string | undefined;
      if (!token) return err(new ServerFailure("bad token", "register"));
      await tokenStore.writeToken(token);
      this.cachedToken = token;
      return ok(token);
    } catch (e: any) {
      return err(new NetworkFailure(e?.message ?? "network error"));
    }
  }

  private async authed(
    token: string,
    method: string,
    path: string,
    body?: any,
  ): Promise<Result<any>> {
    try {
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
      const res = await fetch(`${this.baseUrl()}${path}`, {
        method,
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
        },
        body: body != null ? JSON.stringify(body) : undefined,
        signal: ctrl.signal,
      });
      clearTimeout(to);
      if (res.status >= 200 && res.status < 300) {
        if (res.status === 204) return ok({});
        const text = await res.text();
        if (!text) return ok({});
        return ok(JSON.parse(text));
      }
      let code: string | undefined;
      try {
        const j = await res.json();
        code = j?.e ?? j?.code;
      } catch {}
      return err(new ServerFailure("request failed", code ?? "unknown"));
    } catch (e: any) {
      return err(new NetworkFailure(e?.message ?? "network error"));
    }
  }

  private mapError(res: Response): any {
    return new ServerFailure("request failed", "unknown");
  }

  // ---- public API ----

  async getOrCreateToken(force = false): Promise<Result<string>> {
    return this.ensureRegistered(force);
  }

  async postConsents(token: string, version: number): Promise<Result<boolean>> {
    const r = await this.authed(token, "POST", "/v1/consents", {
      version,
    });
    return r.ok ? ok(true) : err(r.failure);
  }

  async revokeConsent(token: string): Promise<Result<boolean>> {
    const r = await this.authed(token, "DELETE", "/v1/consents");
    return r.ok ? ok(true) : err(r.failure);
  }

  async deleteMe(token: string): Promise<Result<boolean>> {
    const r = await this.authed(token, "DELETE", "/v1/me");
    return r.ok ? ok(true) : err(r.failure);
  }

  async deleteLearning(token: string): Promise<Result<boolean>> {
    const r = await this.authed(token, "DELETE", "/v1/me/learning");
    return r.ok ? ok(true) : err(r.failure);
  }

  async startTrip(
    token: string,
    opts: {
      lineId: number;
      lat: number;
      lng: number;
      accuracyM: number;
      batteryPct: number;
      charging: boolean;
      resume?: boolean;
    },
  ): Promise<Result<TripInstruction>> {
    const r = await this.authed(token, "POST", "/v1/trip", {
      line: opts.lineId,
      lat: opts.lat,
      lng: opts.lng,
      acc: opts.accuracyM,
      bat: opts.batteryPct,
      chg: opts.charging,
      resume: opts.resume ?? false,
    });
    if (!r.ok) return err(r.failure);
    const parsed = TripInstructionSchema.safeParse(r.value);
    if (!parsed.success) return err(new ServerFailure("bad instruction", "bad_request"));
    return ok(parsed.data);
  }

  async pingTrip(
    token: string,
    opts: {
      seq: number;
      lat: number;
      lng: number;
      speedMps: number;
      heading: number | null;
      accuracyM: number;
      batteryPct: number;
      charging: boolean;
      role: string;
    },
  ): Promise<Result<TripInstruction>> {
    const r = await this.authed(token, "POST", "/v1/trip/ping", {
      seq: opts.seq,
      lat: opts.lat,
      lng: opts.lng,
      spd: opts.speedMps,
      hdg: opts.heading,
      acc: opts.accuracyM,
      bat: opts.batteryPct,
      chg: opts.charging,
      role: opts.role,
    });
    if (!r.ok) return err(r.failure);
    const parsed = TripInstructionSchema.safeParse(r.value);
    if (!parsed.success) return err(new ServerFailure("bad instruction", "bad_request"));
    return ok(parsed.data);
  }

  async endTrip(token: string): Promise<Result<boolean>> {
    const r = await this.authed(token, "DELETE", "/v1/trip");
    return r.ok ? ok(true) : err(r.failure);
  }

  async postReport(
    token: string,
    opts: { op: string; kind: string; lineId: number; area?: string },
  ): Promise<Result<ReportDTO[]>> {
    const body: any = { op: opts.op, kind: opts.kind, line: opts.lineId };
    if (opts.area) body.area = opts.area;
    const r = await this.authed(token, "POST", "/v1/reports", body);
    if (!r.ok) return err(r.failure);
    const reports = (r.value?.r ?? []) as any;
    // validate loosely
    return ok(reports as ReportDTO[]);
  }

  async getVehicles(lineId: number): Promise<Result<VehiclesSnapshot>> {
    try {
      const headers: Record<string, string> = {};
      const etag = this.vehiclesEtags.get(lineId);
      if (etag) headers["if-none-match"] = etag;
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
      const res = await fetch(`${this.baseUrl()}/v1/lines/${lineId}/vehicles`, {
        headers,
        signal: ctrl.signal,
      });
      clearTimeout(to);
      if (res.status === 304) {
        const cached = this.vehiclesCache.get(lineId);
        if (cached) return ok(cached);
        return err(new NetworkFailure("vehicles not cached"));
      }
      if (res.status !== 200) {
        let code: string | undefined;
        try {
          const j = await res.json();
          code = j?.e ?? j?.code;
        } catch {}
        return err(new ServerFailure("request failed", code ?? "unknown"));
      }
      const body = await res.json();
      const parsed = VehiclesSnapshotSchema.safeParse(body);
      if (!parsed.success) return err(new ServerFailure("bad snapshot", "bad_request"));
      const snap = parsed.data;
      const newEtag = res.headers.get("etag");
      if (newEtag) {
        this.vehiclesEtags.set(lineId, newEtag);
        this.vehiclesCache.set(lineId, snap);
      }
      return ok(snap);
    } catch (e: any) {
      return err(new NetworkFailure(e?.message ?? "network error"));
    }
  }

  async getLive(): Promise<Result<LiveLines>> {
    try {
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
      const res = await fetch(`${this.baseUrl()}/v1/live`, { signal: ctrl.signal });
      clearTimeout(to);
      if (res.status !== 200) {
        let code: string | undefined;
        try {
          const j = await res.json();
          code = j?.e ?? j?.code;
        } catch {}
        return err(new ServerFailure("request failed", code ?? "unknown"));
      }
      const body = await res.json();
      const parsed = LiveLinesSchema.safeParse(body);
      if (!parsed.success) return err(new ServerFailure("bad live", "bad_request"));
      return ok(parsed.data);
    } catch (e: any) {
      return err(new NetworkFailure(e?.message ?? "network error"));
    }
  }

  async getArrivals(lineId: number): Promise<Result<ArrivalsPayload>> {
    try {
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
      const res = await fetch(`${this.baseUrl()}/v1/lines/${lineId}/arrivals`, {
        signal: ctrl.signal,
      });
      clearTimeout(to);
      if (res.status !== 200) {
        let code: string | undefined;
        try {
          const j = await res.json();
          code = j?.e ?? j?.code;
        } catch {}
        return err(new ServerFailure("request failed", code ?? "unknown"));
      }
      const body = await res.json();
      const parsed = ArrivalsPayloadSchema.safeParse(body);
      if (!parsed.success) return err(new ServerFailure("bad arrivals", "bad_request"));
      return ok(parsed.data);
    } catch (e: any) {
      return err(new NetworkFailure(e?.message ?? "network error"));
    }
  }
}

export const busApi = new BusApi();
export { BusApi as BusApiClient };

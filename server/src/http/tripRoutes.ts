// Trip endpoints wired to the pure engine. Handlers check kill switch,
// blocklist, consent, quotas, and line validity; the engine owns the rest.
// See PLAN.md 6.5 and 6.6. No trip or session ids anywhere.
import { Hono } from "@hono/hono";
import * as v from "@valibot/valibot";
import type { Sql } from "../db/client.ts";
import { guardState } from "../db/guard.ts";
import type { RuntimeConfig } from "../config/runtime.ts";
import type { LineResolver } from "../data/lines.ts";
import { applyPing, endTrip, isGone, startTrip } from "../domain/ping.ts";
import type { Store } from "../state/store.ts";
import { authMiddleware } from "../security/auth.ts";
import { RateLimiter } from "../security/rateLimit.ts";
import { recordHttp403, recordHttp429 } from "../observability/metrics.ts";
import { TripPingBody, TripStartBody } from "./tripSchemas.ts";
import type { EngineConfig, EngineEvent } from "../domain/types.ts";

const BODY_CAP = 1024;

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

type Ctx = {
  get(n: "deviceId"): string;
  json(o: unknown, status?: number): Response;
  header(n: string, v: string): void;
};

export interface TripDeps {
  sql: Sql;
  store: Store;
  lines: LineResolver;
  followerJitterS: number;
  onLineChanged: (lineId: number) => void;
  /** Tunables owned by main.ts; test easy-publish mutates this object. */
  engine: EngineConfig;
  /** Live runtime config, cached in main.ts and refreshed every 30 s. */
  runtime: () => Promise<RuntimeConfig>;
}

type Body = { kind: "json"; value: unknown } | { kind: "media" } | {
  kind: "empty";
};

async function readBody(c: {
  req: { header(n: string): string | undefined; text(): Promise<string> };
}): Promise<Body> {
  const len = c.req.header("content-length");
  const lenNum = len !== undefined ? Number(len) : NaN;
  if (Number.isFinite(lenNum) && lenNum > BODY_CAP) {
    return { kind: "media" };
  }
  if (!(c.req.header("content-type") ?? "").includes("application/json")) {
    return { kind: "media" };
  }
  try {
    const text = await c.req.text();
    if (text.length > BODY_CAP) return { kind: "media" };
    if (text.trim() === "") return { kind: "empty" };
    return { kind: "json", value: JSON.parse(text) };
  } catch {
    return { kind: "empty" };
  }
}

function jitterS(maxS: number): number {
  // Non-crypto randomness is plenty for schedule jitter.
  return Math.round((Math.random() * 2 - 1) * maxS);
}

export function buildTripRoutes(deps: TripDeps): Hono<Vars> {
  const app = new Hono<Vars>();
  const auth = authMiddleware(deps.sql);
  const startsPerDevice = new RateLimiter(6, 3600 * 1000);
  const resumesPerDevice = new RateLimiter(6, 600 * 1000);
  const pingsPerDevice = new RateLimiter(30, 60 * 1000);
  const endsPerDevice = new RateLimiter(30, 60 * 1000);
  const cfg = deps.engine;

  /** Shared preconditions. Returns a response when the call must stop. */
  async function guard(c: Ctx, deviceId: string): Promise<Response | null> {
    // Runtime config is cached (refreshed every 30 s), never re-read
    // per request. Kill-switch and consent bumps apply within ~30 s.
    // Block plus consent arrive in one round trip (db/guard.ts).
    const rt = await deps.runtime();
    if (!rt.serviceEnabled) {
      c.header("Retry-After", "30");
      return c.json({ e: "maint" }, 503);
    }
    const state = await guardState(deps.sql, deviceId);
    if (state.blocked) {
      recordHttp403();
      return c.json({ e: "blocked" }, 403);
    }
    if (state.consent !== rt.consentVersion) {
      recordHttp403();
      return c.json({ e: "consent" }, 403);
    }
    return null;
  }

  app.post("/v1/trip", auth, async (c) => {
    const stopped = await guard(c, c.get("deviceId"));
    if (stopped) return stopped;
    const deviceId = c.get("deviceId");
    const body = await readBody(c);
    if (body.kind !== "json") {
      return c.json(
        { e: body.kind === "media" ? "media" : "bad_request" },
        body.kind === "media" ? 415 : 400,
      );
    }
    const parsed = v.safeParse(TripStartBody, body.value);
    if (!parsed.success) return c.json({ e: "bad_request" }, 400);
    const line = deps.lines(parsed.output.line);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const resume = parsed.output.resume ?? false;
    const limiter = resume ? resumesPerDevice : startsPerDevice;
    if (!limiter.hit(deviceId, Date.now())) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "quota" }, 429);
    }
    const events: EngineEvent[] = [];
    const out = startTrip(
      deps.store,
      events,
      deviceId,
      { id: line.id, isActive: line.isActive },
      {
        lat: parsed.output.lat,
        lng: parsed.output.lng,
        speedMps: 0,
        heading: null,
        accuracyM: parsed.output.acc,
        batteryPct: parsed.output.bat,
        charging: parsed.output.chg,
        seq: 0,
        role: "W",
      },
      Date.now(),
      cfg,
    );
    if (!out.ok) {
      if (out.code === "line") return c.json({ e: "line" }, 404);
      if (out.code === "area") return c.json({ e: "area" }, 422);
      if (out.code === "capacity") {
        c.header("Retry-After", "60");
        return c.json({ e: "capacity" }, 503);
      }
      return c.json({ e: "bad_request" }, 400);
    }
    return c.json({ r: out.role, n: out.intervalS }, 201);
  });

  app.post("/v1/trip/ping", auth, async (c) => {
    const stopped = await guard(c, c.get("deviceId"));
    if (stopped) return stopped;
    const deviceId = c.get("deviceId");
    if (!pingsPerDevice.hit(deviceId, Date.now())) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "rate" }, 429);
    }
    const body = await readBody(c);
    if (body.kind !== "json") {
      return c.json(
        { e: body.kind === "media" ? "media" : "bad_request" },
        body.kind === "media" ? 415 : 400,
      );
    }
    const parsed = v.safeParse(TripPingBody, body.value);
    if (!parsed.success) return c.json({ e: "bad_request" }, 400);
    const trip = deps.store.trips.get(deviceId);
    const lineId = trip?.lineId;
    const route = trip ? deps.lines(trip.lineId)?.route ?? null : null;
    const events: EngineEvent[] = [];
    const out = applyPing(
      deps.store,
      events,
      deviceId,
      route,
      {
        lat: parsed.output.lat,
        lng: parsed.output.lng,
        speedMps: parsed.output.spd,
        heading: parsed.output.hdg,
        accuracyM: parsed.output.acc,
        batteryPct: parsed.output.bat,
        charging: parsed.output.chg,
        seq: parsed.output.seq,
        role: parsed.output.role,
      },
      Date.now(),
      cfg,
      jitterS(deps.followerJitterS),
    );
    if (isGone(out)) return c.json({ e: "gone" }, 404);
    if (
      lineId !== undefined && events.some((e) => e.kind === "vehicleUpdated")
    ) {
      deps.onLineChanged(lineId);
    }
    if (out.end) return c.json({ r: out.role, n: out.intervalS, e: out.end });
    return c.json({ r: out.role, n: out.intervalS });
  });

  // End intentionally skips guard(): ending is cleanup and must succeed
  // even under kill switch, blocklist, or consent mismatch, so a device
  // is never stranded in-trip while reads degrade. Rate limit still
  // applies. SECURITY: auth runs first; endTrip is idempotent and scoped
  // to the caller device id only.
  app.delete("/v1/trip", auth, (c) => {
    const deviceId = c.get("deviceId");
    if (!endsPerDevice.hit(deviceId, Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    endTrip(deps.store, [], deviceId);
    return c.body(null, 204);
  });

  return app;
}

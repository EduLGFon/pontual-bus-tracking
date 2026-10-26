// Public read endpoints and the read-only stream. Vehicle positions and
// passenger reports are public by design; reads need no login. See PLAN.md
// 6.5 and 6.8.
import { Hono } from "@hono/hono";
import type { LineResolver } from "../data/lines.ts";
import { arrivalsPayload } from "../domain/arrivals.ts";
import { decodePolyline } from "../domain/geo.ts";
import { predictEta } from "../learning/predictor.ts";
import { defaultEngineConfig } from "../domain/types.ts";
import {
  recordHttp403,
  recordHttp429,
  recordWsCapacityRefused,
  recordWsConnect,
} from "../observability/metrics.ts";
import { lineSnapshot, livePayload, snapshotRows } from "../state/snapshots.ts";
import type { Store } from "../state/store.ts";
import { RateLimiter } from "../security/rateLimit.ts";
import { reportRows } from "../domain/reports.ts";
import { Hub } from "../ws/hub.ts";

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

export interface ReadDeps {
  store: Store;
  lines: LineResolver;
  hub: Hub;
  allowedOrigins: string[];
  trustCloudflare: boolean;
  /** Sync switch so WS snapshots stay synchronous. */
  reportsEnabled: () => boolean;
  /** Optional learning consumer. */
  learning?: import("../learning/consumer.ts").LearningConsumer;
}

export function buildReadRoutes(deps: ReadDeps): Hono<Vars> {
  const app = new Hono<Vars>();
  const cfg = defaultEngineConfig();
  const vehiclesPerIp = new RateLimiter(120, 60 * 1000);
  const livePerIp = new RateLimiter(60, 60 * 1000);
  const ipOf = (c: { get(n: "clientIp"): string }) => c.get("clientIp");

  app.get("/v1/lines/:id/vehicles", (c) => {
    if (!vehiclesPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "rate" }, 429);
    }
    const id = Number(c.req.param("id"));
    if (!Number.isInteger(id) || id < 1) return c.json({ e: "line" }, 404);
    const line = deps.lines(id);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const inm = c.req.header("if-none-match");
    // Build the snapshot before comparing: a cached ETag would hide a
    // report change until some other request refreshed the cache. The
    // payload is tiny and the build is cheap.
    const { body, etag } = lineSnapshot(
      deps.store,
      id,
      Date.now(),
      cfg.publishTtlS,
      cfg.memberAliveS,
      deps.reportsEnabled(),
    );
    if (inm === etag) {
      return c.body(null, 304);
    }
    c.header("ETag", etag);
    c.header("Cache-Control", "public, max-age=5");
    return c.body(body, 200, { "content-type": "application/json" });
  });

  app.get("/v1/live", (c) => {
    if (!livePerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "rate" }, 429);
    }
    const { body } = livePayload(
      deps.store,
      Date.now(),
      cfg.publishTtlS,
      cfg.memberAliveS,
    );
    c.header("Cache-Control", "public, max-age=10");
    return c.body(body, 200, { "content-type": "application/json" });
  });

  // D30: anonymous recent passages for one line. Timestamps only, no
  // positions and no ids. Additive; timetables stay the fallback.
  app.get("/v1/lines/:id/arrivals", (c) => {
    if (!vehiclesPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      recordHttp429();
      return c.json({ e: "rate" }, 429);
    }
    const id = Number(c.req.param("id"));
    if (!Number.isInteger(id) || id < 1) return c.json({ e: "line" }, 404);
    const line = deps.lines(id);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    c.header("Cache-Control", "public, max-age=10");
    return c.json(arrivalsPayload(deps.store, id, Date.now()));
  });

  app.get("/v1/stream", (c) => {
    const origin = c.req.header("origin");
    if (origin && !deps.allowedOrigins.includes(origin)) {
      recordHttp403();
      return c.json({ e: "auth" }, 403);
    }
    const upgrade = c.req.header("upgrade");
    if (!upgrade || upgrade.toLowerCase() !== "websocket") {
      return c.json({ e: "bad_request" }, 400);
    }
    const ip = ipOf(c);
    // Refuse before upgrading: a close frame cannot be delivered on a
    // socket whose handshake never completed, so answer 503 with a
    // Retry-After the client can honor instead of a stillborn 101.
    if (!deps.hub.fits(ip)) {
      c.header("Retry-After", "5");
      recordWsCapacityRefused();
      return c.json({ e: "capacity" }, 503);
    }
    const { socket, response } = Deno.upgradeWebSocket(c.req.raw, {
      idleTimeout: 60,
    });
    const conn = deps.hub.connect(socket, ip);
    if (!conn) {
      recordWsCapacityRefused();
      socket.close(1013, "capacity");
      return response;
    }
    recordWsConnect();
    socket.onmessage = (ev) => {
      // One timestamp for rate limiting and the snapshot: two clocks
      // could straddle a second boundary and disagree by one second.
      const nowMs = Date.now();
      const reply = deps.hub.onMessage(
        conn,
        String(ev.data),
        nowMs,
        (lineId) => {
          const line = deps.lines(lineId);
          if (!line || !line.isActive) return null;
          try {
            const snap = {
              l: lineId,
              t: Math.floor(nowMs / 1000),
              v: snapshotRows(
                deps.store,
                lineId,
                nowMs,
                cfg.publishTtlS,
                cfg.memberAliveS,
              ),
              r: deps.reportsEnabled()
                ? reportRows(deps.store, lineId, nowMs)
                : [],
            };
            return JSON.stringify(snap);
          } catch {
            return null;
          }
        },
      );
      if (reply !== null) {
        try {
          socket.send(reply);
        } catch {
          deps.hub.disconnect(conn);
        }
      } else if (conn.lineId !== null) {
        // Subscribed to an unknown or inactive line: reject the socket.
        try {
          if (socket.readyState === 1) socket.close(1007, "bad message");
        } catch {
          // Ignore close failures.
        }
        deps.hub.disconnect(conn);
      }
    };
    socket.onclose = () => deps.hub.disconnect(conn);
    socket.onerror = () => deps.hub.disconnect(conn);
    return response;
  });

  // Learning endpoints (optional). Returns 404 when no consumer is wired
  // or the subsystem is disabled.
  const learningPerIp = new RateLimiter(60, 60 * 1000);
  const learningEtaPerIp = new RateLimiter(120, 60 * 1000);

  app.get("/v1/lines/:id/learned-route", async (c) => {
    if (!deps.learning || !deps.learning.isEnabled()) {
      return c.json({ e: "not_found" }, 404);
    }
    if (!learningPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const id = Number(c.req.param("id"));
    if (!Number.isInteger(id) || id < 1) return c.json({ e: "line" }, 404);
    const line = deps.lines(id);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const r = await deps.learning.learnedRoute(id);
    if (!r) {
      // fallback to static route from server data bundle
      const staticRoute = line.route ?? null;
      return c.json({
        v: 0,
        dir: 0,
        polyline: staticRoute,
        points: staticRoute ? null : 0,
        trips: 0,
        computed_at: null,
        fallback: true,
      }, 200);
    }
    c.header("Cache-Control", "public, max-age=300");
    return c.json({
      v: r.version,
      dir: 0,
      polyline: r.polyline,
      points: null,
      trips: r.trips,
      computed_at: r.computedAt,
      fallback: false,
    }, 200);
  });

  app.get("/v1/lines/:id/stops", async (c) => {
    if (!deps.learning || !deps.learning.isEnabled()) {
      return c.json({ e: "not_found" }, 404);
    }
    if (!learningPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const id = Number(c.req.param("id"));
    if (!Number.isInteger(id) || id < 1) return c.json({ e: "line" }, 404);
    const line = deps.lines(id);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const stops = await deps.learning.learnedStops(id);
    if (stops.length === 0) {
      return c.json({ dir: 0, stops: [], fallback: true }, 200);
    }
    c.header("Cache-Control", "public, max-age=300");
    return c.json({
      dir: 0,
      stops: stops.map((s) => ({
        id: s.id,
        i: s.ordinal,
        lat: s.lat,
        lng: s.lng,
        r: s.radiusM,
        n: s.passes,
      })),
      fallback: false,
    }, 200);
  });

  app.get("/v1/lines/:id/eta", async (c) => {
    if (!deps.learning || !deps.learning.isEnabled()) {
      return c.json({ e: "not_found" }, 404);
    }
    if (!learningEtaPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const id = Number(c.req.param("id"));
    if (!Number.isInteger(id) || id < 1) return c.json({ e: "line" }, 404);
    const line = deps.lines(id);
    if (!line || !line.isActive) return c.json({ e: "line" }, 404);
    const stopId = c.req.query("stop");
    if (!stopId) return c.json({ e: "bad_request" }, 400);
    const cfg = deps.learning.configSnapshot();
    const route = await deps.learning.learnedRoute(id);
    const routePts = route?.polyline
      ? decodePolyline(route.polyline, 5)
      : (line.route ? [...line.route.pts] : []);
    const stops = await deps.learning.learnedStops(id);
    const stopList = stops.map((s) => ({ id: s.id, lat: s.lat, lng: s.lng }));
    const vehicleParam = c.req.query("vehicle");
    const nowMs = Date.now();
    const vehicles = deps.store
      ? [...deps.store.vehicles.values()].filter((v) => v.lineId === id)
      : [];
    const targets = vehicleParam
      ? vehicles.filter((v) => String(v.id) === vehicleParam)
      : vehicles;
    const items: Array<
      { vehicle: number; eta_s: number; conf: string; n: number }
    > = [];
    for (const v of targets) {
      const res = await predictEta(
        deps.learning,
        cfg,
        id,
        0,
        v.lat,
        v.lng,
        v.paceMps,
        stopId,
        stopList,
        routePts,
        nowMs,
      );
      items.push({
        vehicle: v.id,
        eta_s: res.etaS,
        conf: res.confidence,
        n: res.sampleCount,
      });
    }
    c.header("Cache-Control", "public, max-age=10");
    return c.json({
      stop: stopId,
      now: Math.floor(nowMs / 1000),
      items,
      next_scheduled_s: null,
    }, 200);
  });

  // Bulk learned routes (for place search). Returns one entry per
  // (line, direction) with an active learned route.
  app.get("/v1/learned-routes", async (c) => {
    if (!deps.learning || !deps.learning.isEnabled()) {
      return c.json({ e: "not_found" }, 404);
    }
    if (!learningPerIp.hit(ipOf(c), Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const bboxRaw = c.req.query("bbox");
    let bbox:
      | { latMin: number; lngMin: number; latMax: number; lngMax: number }
      | null = null;
    if (bboxRaw) {
      const parts = bboxRaw.split(",").map((s) => Number(s.trim()));
      if (parts.length !== 4 || parts.some((n) => !Number.isFinite(n))) {
        return c.json({ e: "bad_request" }, 400);
      }
      bbox = {
        latMin: Math.min(parts[0], parts[2]),
        lngMin: Math.min(parts[1], parts[3]),
        latMax: Math.max(parts[0], parts[2]),
        lngMax: Math.max(parts[1], parts[3]),
      };
    }
    const routes = await deps.learning.allLearnedRoutes();
    const stopsByLineDir = new Map<
      string,
      Awaited<ReturnType<typeof deps.learning.allLearnedStops>>[number]["stops"]
    >();
    for (const s of await deps.learning.allLearnedStops()) {
      stopsByLineDir.set(`${s.lineId}:${s.direction}`, s.stops);
    }
    const entries: Array<Record<string, unknown>> = [];
    for (const r of routes) {
      const line = deps.lines(r.lineId);
      if (!line || !line.isActive) continue;
      const pts = decodePolyline(r.polyline, 5);
      if (bbox) {
        const hit = pts.some((p) =>
          p.lat >= bbox!.latMin && p.lat <= bbox!.latMax &&
          p.lng >= bbox!.lngMin && p.lng <= bbox!.lngMax
        ) ||
          (stopsByLineDir.get(`${r.lineId}:${r.direction}`) ?? []).some((s) =>
            s.lat >= bbox!.latMin && s.lat <= bbox!.latMax &&
            s.lng >= bbox!.lngMin && s.lng <= bbox!.lngMax
          );
        if (!hit) {
          continue;
        }
      }
      entries.push({
        line: r.lineId,
        code: line.code ?? String(r.lineId),
        dir: r.direction,
        polyline: r.polyline,
        trips: r.trips,
        computed_at: r.computedAt,
        stops: (stopsByLineDir.get(`${r.lineId}:${r.direction}`) ?? []).map((
          s,
        ) => ({
          id: s.id,
          i: s.ordinal,
          lat: s.lat,
          lng: s.lng,
          r: s.radiusM,
          n: s.passes,
        })),
      });
    }
    c.header("Cache-Control", "public, max-age=300");
    return c.json({ v: 1, routes: entries }, 200);
  });

  return app;
}

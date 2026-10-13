// Public read endpoints and the read-only stream. Vehicle positions are
// public by design; reads need no login. See PLAN.md 6.5 and 6.8.
import { Hono } from "@hono/hono";
import type { LineResolver } from "../data/lines.ts";
import { arrivalsPayload } from "../domain/arrivals.ts";
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
}

export function buildReadRoutes(deps: ReadDeps): Hono<Vars> {
  const app = new Hono<Vars>();
  const cfg = defaultEngineConfig();
  const vehiclesPerIp = new RateLimiter(120, 60 * 1000);
  const livePerIp = new RateLimiter(60, 60 * 1000);
  // Last snapshot per line. ETag equality proves identical bytes, so a
  // matching If-None-Match answers 304 without rebuilding. Bounded by
  // line count (tens of entries, each a few KB at most).
  const memo = new Map<number, { body: string; etag: string }>();
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
    const cached = memo.get(id);
    if (cached && inm === cached.etag) {
      return c.body(null, 304);
    }
    const { body, etag } = lineSnapshot(
      deps.store,
      id,
      Date.now(),
      cfg.publishTtlS,
    );
    memo.set(id, { body, etag });
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
    const { body } = livePayload(deps.store, Date.now(), cfg.publishTtlS);
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
            return JSON.stringify({
              l: lineId,
              t: Math.floor(nowMs / 1000),
              v: snapshotRows(deps.store, lineId, nowMs, cfg.publishTtlS),
            });
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

  return app;
}

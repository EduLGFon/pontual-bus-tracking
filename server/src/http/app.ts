// Hono app. Middleware order per PLAN.md 6.9: request id, secure headers,
// client IP resolution, then per-route body limit, rate limit, auth, schema
// validation, handler, and the global error handler.
import { Hono } from "@hono/hono";
import type { Sql } from "../db/client.ts";
import type { EngineConfig } from "../domain/types.ts";
import { Log } from "../observability/log.ts";
import { loadRuntimeConfig } from "../config/runtime.ts";
import type { RuntimeConfig } from "../config/runtime.ts";
import { recordHealthCheck, recordRequest } from "../observability/metrics.ts";
import { clientIp } from "../security/clientIp.ts";
import type { LineResolver } from "../data/lines.ts";
import type { Store } from "../state/store.ts";
import { buildAccountRoutes } from "./routes.ts";
import { buildDiagnosticsRoutes } from "./diagRoutes.ts";
import { buildReadRoutes } from "./readRoutes.ts";
import { buildReportRoutes } from "./reportRoutes.ts";
import { buildTripRoutes } from "./tripRoutes.ts";
import type { Hub } from "../ws/hub.ts";
import type { LearningConsumer } from "../learning/consumer.ts";

export interface AppOptions {
  sql: Sql | null;
  store: Store | null;
  lines: LineResolver;
  hub: Hub | null;
  followerJitterS: number;
  trustCloudflare: boolean;
  allowedOrigins: string[];
  onLineChanged: (lineId: number) => void;
  reportsEnabled: () => boolean;
  /** Tunables owned by main.ts; test easy-publish mutates this object. */
  engine: EngineConfig;
  /** Optional learning consumer. When absent, learning endpoints return 404. */
  learning?: LearningConsumer;
  /**
   * Live runtime config. Production passes a cached getter refreshed
   * every 30 s; when omitted, each request loads it (tests, local).
   */
  runtime?: () => Promise<RuntimeConfig>;
}

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

export function buildApp(opts: AppOptions): Hono<Vars> {
  const app = new Hono<Vars>();

  app.use("*", async (c, next) => {
    const requestId = crypto.randomUUID();
    c.set("requestId", requestId);
    const socketAddr = c.req.header("x-socket-addr") ?? null;
    c.set(
      "clientIp",
      clientIp(
        socketAddr,
        c.req.header("cf-connecting-ip") ?? null,
        opts.trustCloudflare,
      ),
    );
    // Secure defaults before the handler; routes override cache-control.
    c.header("x-request-id", requestId);
    c.header("x-content-type-options", "nosniff");
    c.header("referrer-policy", "no-referrer");
    c.header("cache-control", "no-store");
    const origin = c.req.header("origin");
    const normOrigin = origin ? origin.replace(/\/+$/, "") : null;
    if (origin && normOrigin && opts.allowedOrigins.includes(normOrigin)) {
      c.header("access-control-allow-origin", origin);
      c.header("vary", "Origin");
    }
    const start = Date.now();
    await next();
    const durationMs = Date.now() - start;
    recordRequest();
    // Debug only: at ping frequency this line would dominate CPU and
    // log volume. Errors still surface via the global error handler.
    Log.debug("request", {
      method: c.req.method,
      route: c.req.routePath,
      status: c.res.status,
      durationMs,
      requestId,
    });
  });

  app.options("*", (c) => {
    // CORS preflight: browsers send OPTIONS before non-simple requests
    // (POST with a JSON body, DELETE, authed calls). Without this the
    // preflight 404s and the browser blocks the real request.
    const origin = c.req.header("origin");
    const normOrigin = origin ? origin.replace(/\/+$/, "") : null;
    if (origin && normOrigin && opts.allowedOrigins.includes(normOrigin)) {
      c.header("access-control-allow-origin", origin);
      c.header("vary", "Origin");
      c.header("access-control-allow-methods", "GET, POST, DELETE, OPTIONS");
      c.header(
        "access-control-allow-headers",
        "authorization, content-type, if-none-match",
      );
      c.header("access-control-max-age", "86400");
    }
    return c.body(null, 204);
  });

  app.get("/v1/health", (c) => {
    recordHealthCheck();
    return c.json({ ok: true });
  });

  if (opts.sql) {
    const sql: Sql = opts.sql;
    // Without an injected getter, load per request (old behavior).
    const runtime = opts.runtime ??
      (() => loadRuntimeConfig(sql));
    app.route(
      "/",
      buildAccountRoutes({
        sql,
        runtime,
        store: opts.store ?? undefined,
        onLineChanged: opts.onLineChanged,
      }),
    );
    app.route(
      "/",
      buildDiagnosticsRoutes({
        sql,
        runtime,
      }),
    );
  }
  if (opts.sql && opts.store) {
    const sql: Sql = opts.sql;
    const runtime = opts.runtime ??
      (() => loadRuntimeConfig(sql));
    app.route(
      "/",
      buildTripRoutes({
        sql,
        store: opts.store,
        lines: opts.lines,
        followerJitterS: opts.followerJitterS,
        onLineChanged: opts.onLineChanged,
        engine: opts.engine,
        runtime,
        learning: opts.learning,
      }),
    );
    app.route(
      "/",
      buildReportRoutes({
        sql,
        store: opts.store,
        lines: opts.lines,
        runtime,
        onLineChanged: opts.onLineChanged,
      }),
    );
  }
  if (opts.store && opts.hub) {
    app.route(
      "/",
      buildReadRoutes({
        store: opts.store,
        lines: opts.lines,
        hub: opts.hub,
        allowedOrigins: opts.allowedOrigins,
        trustCloudflare: opts.trustCloudflare,
        reportsEnabled: opts.reportsEnabled,
        learning: opts.learning,
      }),
    );
  }

  app.notFound((c) => c.json({ code: "not_found" }, 404));
  app.onError((err, c) => {
    // Server Error text only, never request data. RequestId correlates
    // with the request log line above. Truncated to bound log volume.
    // PRIVACY: String(err) must stay an Error message; never interpolate
    // fixes, tokens, or ids here.
    let requestId = "unknown";
    try {
      requestId = c.get("requestId") ?? "unknown";
    } catch {
      // Context may be partially initialized; keep the fallback.
    }
    Log.error("unhandled", { requestId, err: String(err).slice(0, 200) });
    return c.json({ code: "internal" }, 500);
  });

  return app;
}

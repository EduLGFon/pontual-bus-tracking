// Diagnostics ingestion. First-party only, opt-in, redacted bundles.
import { Hono } from "@hono/hono";
import type { Sql } from "../db/client.ts";
import type { RuntimeConfig } from "../config/runtime.ts";
import { insertDiagnostic } from "../db/diagnostics.ts";
import { findDeviceByTokenHash } from "../db/devices.ts";
import { tokenHash } from "../security/token.ts";
import { RateLimiter } from "../security/rateLimit.ts";
import { readJsonBody } from "./body.ts";
import { DiagnosticsBody, parseJson } from "./schemas.ts";

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

export function buildDiagnosticsRoutes(
  deps: { sql: Sql; runtime: () => Promise<RuntimeConfig> },
): Hono<Vars> {
  const sql = deps.sql;
  const app = new Hono<Vars>();
  const perDevice = new RateLimiter(5, 3600 * 1000);
  const perIp = new RateLimiter(20, 3600 * 1000);
  const global = new RateLimiter(2000, 3600 * 1000);

  app.post("/v1/diagnostics", async (c) => {
    const now = Date.now();
    const ip = c.get("clientIp");
    if (!global.hit("global", now)) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const authHeader = c.req.header("authorization") ?? null;
    const token = authHeader?.toLowerCase().startsWith("bearer ")
      ? authHeader.slice(7).trim()
      : null;
    let deviceId: string | null = null;
    if (token && token.length > 0) {
      try {
        const hash = await tokenHash(token);
        const row = await findDeviceByTokenHash(sql, hash);
        if (row && row.expiresAt.getTime() > now) deviceId = row.id;
      } catch {
        deviceId = null;
      }
    }
    const rlKey = deviceId ?? ip;
    const limiter = deviceId ? perDevice : perIp;
    if (!limiter.hit(rlKey, now)) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const body = await readJsonBody(c, 65536);
    if (body.kind === "media") return c.json({ e: "media" }, 415);
    if (body.kind !== "json") return c.json({ e: "bad_request" }, 400);
    const parsed = parseJson(DiagnosticsBody, body.value);
    if (parsed === null) return c.json({ e: "bad_request" }, 400);
    if (!parsed.optIn) return c.json({ e: "opt_out" }, 403);
    try {
      await insertDiagnostic(sql, deviceId, parsed);
    } catch {
      return c.json({ e: "internal" }, 500);
    }
    return c.body(null, 204);
  });

  return app;
}

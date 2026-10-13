// Device, consent, and delete routes. Handlers stay thin: parse,
// authenticate, call a repository, format the response.
// See PLAN.md 6.5. No trip or session ids anywhere.
import type { Context } from "@hono/hono";
import { Hono } from "@hono/hono";
import type { Sql } from "../db/client.ts";
import { deleteDevice, insertDevice } from "../db/devices.ts";
import { recordConsent } from "../db/consents.ts";
import type { RuntimeConfig } from "../config/runtime.ts";
import { ConsentsBody, DevicesBody, parseJson } from "./schemas.ts";
import { authMiddleware, evictTokenHash } from "../security/auth.ts";
import {
  bearerToken,
  generateToken,
  hashHex,
  tokenHash,
} from "../security/token.ts";
import { RateLimiter } from "../security/rateLimit.ts";

const DEVICE_TTL_MS = 30 * 86400 * 1000;
const BODY_CAP = 1024;

type Vars = {
  Variables: { requestId: string; deviceId: string; clientIp: string };
};

type Body = { kind: "json"; value: unknown } | { kind: "media" } | {
  kind: "empty";
};

async function readBody(c: Context<Vars>): Promise<Body> {
  const len = c.req.header("content-length");
  const lenNum = len !== undefined ? Number(len) : NaN;
  if (Number.isFinite(lenNum) && lenNum > BODY_CAP) {
    return { kind: "media" };
  }
  const ct = c.req.header("content-type") ?? "";
  if (!ct.includes("application/json")) return { kind: "media" };
  try {
    const text = await c.req.text();
    if (text.length > BODY_CAP) return { kind: "media" };
    if (text.trim() === "") return { kind: "empty" };
    return { kind: "json", value: JSON.parse(text) };
  } catch {
    return { kind: "empty" };
  }
}

export function buildAccountRoutes(deps: {
  sql: Sql;
  runtime: () => Promise<RuntimeConfig>;
}): Hono<Vars> {
  const sql = deps.sql;
  const runtime = deps.runtime;
  const app = new Hono<Vars>();
  const registerPerIp = new RateLimiter(60, 3600 * 1000);
  const registerGlobal = new RateLimiter(600, 3600 * 1000);
  const consentsPerDevice = new RateLimiter(10, 3600 * 1000);
  const deletePerDevice = new RateLimiter(5, 3600 * 1000);

  app.post("/v1/devices", async (c) => {
    const now = Date.now();
    const ip = c.get("clientIp");
    if (!registerGlobal.hit("global", now) || !registerPerIp.hit(ip, now)) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const body = await readBody(c);
    if (body.kind === "media") return c.json({ e: "media" }, 415);
    const value = body.kind === "json" ? body.value : {};
    if (parseJson(DevicesBody, value) === null) {
      return c.json({ e: "bad_request" }, 400);
    }
    const token = generateToken();
    const hash = await tokenHash(token);
    const expiresAt = new Date(now + DEVICE_TTL_MS);
    const row = await insertDevice(sql, hash, expiresAt);
    return c.json(
      { token, exp: Math.floor(expiresAt.getTime() / 1000), id: row.id },
      201,
    );
  });

  const auth = authMiddleware(sql);

  app.post("/v1/consents", auth, async (c) => {
    const deviceId = c.get("deviceId");
    if (!consentsPerDevice.hit(deviceId, Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const body = await readBody(c);
    if (body.kind !== "json") {
      return body.kind === "media"
        ? c.json({ e: "media" }, 415)
        : c.json({ e: "bad_request" }, 400);
    }
    const parsed = parseJson(ConsentsBody, body.value);
    if (parsed === null) return c.json({ e: "bad_request" }, 400);
    if (parsed.version !== (await runtime()).consentVersion) {
      return c.json({ e: "consent" }, 403);
    }
    await recordConsent(sql, deviceId, parsed.version);
    return c.json({ ok: true });
  });

  app.delete("/v1/me", auth, async (c) => {
    const deviceId = c.get("deviceId");
    if (!deletePerDevice.hit(deviceId, Date.now())) {
      c.header("Retry-After", "60");
      return c.json({ e: "rate" }, 429);
    }
    const token = bearerToken(c.req.header("authorization") ?? null);
    await deleteDevice(sql, deviceId);
    if (token) evictTokenHash(hashHex(await tokenHash(token)));
    return c.body(null, 204);
  });

  return app;
}

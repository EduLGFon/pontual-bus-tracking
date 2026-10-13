// Bearer auth. The device id comes from the verified token only.
// SECURITY: no client-supplied ids anywhere; one active trip per device is
// enforced later by the engine. Unknown or expired tokens behave exactly
// like missing ones: 401 with a generic code.
import type { Context, Next } from "@hono/hono";
import type { Sql } from "../db/client.ts";
import { findDeviceByTokenHash } from "../db/devices.ts";
import { bearerToken, hashHex, tokenHash } from "./token.ts";

interface CacheEntry {
  deviceId: string;
  // Cache entry expiry (lookup TTL). Separate from the token expiry below:
  // a cached row must never authorize past the token's own expiresAt.
  cacheUntilMs: number;
  tokenExpiresAtMs: number;
}

const cache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 60 * 1000;
// Upper bound: entries are tiny, but uptime is measured in weeks and
// every registered device ever adds one until evicted on delete.
const CACHE_MAX = 5000;

/** Evict a token hash from the cache (revocation path). */
export function evictTokenHash(hashHexKey: string): void {
  cache.delete(hashHexKey);
}

export function authMiddleware(sql: Sql) {
  return async (
    c: Context<{ Variables: { requestId: string; deviceId: string } }>,
    next: Next,
  ) => {
    const token = bearerToken(c.req.header("authorization") ?? null);
    if (!token) return c.json({ e: "auth" }, 401);
    const hash = await tokenHash(token);
    const key = hashHex(hash);
    const now = Date.now();
    const hit = cache.get(key);
    if (hit && hit.cacheUntilMs > now && hit.tokenExpiresAtMs > now) {
      c.set("deviceId", hit.deviceId);
      await next();
      return;
    }
    if (hit) cache.delete(key);
    const row = await findDeviceByTokenHash(sql, hash);
    if (!row || row.expiresAt.getTime() <= now) {
      return c.json({ e: "auth" }, 401);
    }
    cache.set(key, {
      deviceId: row.id,
      cacheUntilMs: now + CACHE_TTL_MS,
      tokenExpiresAtMs: row.expiresAt.getTime(),
    });
    if (cache.size > CACHE_MAX) {
      const oldest = cache.keys().next();
      if (!oldest.done) cache.delete(oldest.value);
    }
    c.set("deviceId", row.id);
    await next();
  };
}

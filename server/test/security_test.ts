// T08 security tests: AC01, AC03, AC11, AC13, AC18, AC23.
// HTTP-level tests run the real app in-process against test PostgreSQL.
// See PLAN.md 12.6.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb } from "../src/db/client.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";
import { findDeviceByTokenHash } from "../src/db/devices.ts";
import { tokenHash } from "../src/security/token.ts";

function testDbUrl(): string {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  return url;
}

async function truncate(): Promise<void> {
  const sql = openDb(testDbUrl());
  try {
    await sql`truncate devices, app_config restart identity cascade`;
  } finally {
    await sql.end();
  }
}

function app() {
  const sql = openDb(testDbUrl());
  const hono = buildApp({
    sql,
    store: createStore(),
    lines: registryResolver([{ id: 7, isActive: true, route: null }]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: () => {},
    reportsEnabled: () => false,
    trustCloudflare: false,
    allowedOrigins: ["http://127.0.0.1:8080"],
    engine: defaultEngineConfig(),
  });
  return { sql, hono };
}

async function register(
  hono: ReturnType<typeof buildApp>,
): Promise<{ token: string; id: string }> {
  const res = await hono.request("/v1/devices", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assertEquals(res.status, 201);
  return await res.json() as { token: string; id: string };
}

Deno.test("AC01: auth endpoints reject missing, malformed, unknown tokens", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    for (const path of ["/v1/consents", "/v1/me"]) {
      const noToken = await hono.request(path, {
        method: path === "/v1/me" ? "DELETE" : "POST",
        headers: { "content-type": "application/json" },
        body: "{}",
      });
      assertEquals(noToken.status, 401);
      assertEquals(await noToken.json(), { e: "auth" });

      const malformed = await hono.request(path, {
        method: path === "/v1/me" ? "DELETE" : "POST",
        headers: {
          "content-type": "application/json",
          authorization: "Bearer bogus",
        },
        body: "{}",
      });
      assertEquals(malformed.status, 401);

      const unknown = "bm1_" + "A".repeat(43);
      const unknownRes = await hono.request(path, {
        method: path === "/v1/me" ? "DELETE" : "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${unknown}`,
        },
        body: "{}",
      });
      assertEquals(unknownRes.status, 401);
      assertEquals(await unknownRes.json(), { e: "auth" });
    }

    const reg = await hono.request("/v1/devices", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    assertEquals(reg.status, 201);
    const creds = await reg.json() as { token: string; id: string };
    await sql`update devices set expires_at = now() - interval '1 second' where id = ${creds.id}`;
    const expired = await hono.request("/v1/consents", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${creds.token}`,
      },
      body: '{"version":1}',
    });
    assertEquals(expired.status, 401);
    assertEquals(await expired.json(), { e: "auth" });
  } finally {
    await sql.end();
  }
});

Deno.test("AC11: schema fuzz on bodies returns generic errors", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const { token } = await register(hono);
    const cases: { body: string; contentType: string; status: number }[] = [
      { body: "null", contentType: "application/json", status: 400 },
      { body: '{"version":"x"}', contentType: "application/json", status: 400 },
      {
        body: '{"version":1,"extra":2}',
        contentType: "application/json",
        status: 400,
      },
      { body: '{"version":1}', contentType: "text/plain", status: 415 },
      { body: "x".repeat(2048), contentType: "application/json", status: 415 },
    ];
    for (const tc of cases) {
      const res = await hono.request("/v1/consents", {
        method: "POST",
        headers: {
          "content-type": tc.contentType,
          authorization: `Bearer ${token}`,
        },
        body: tc.body,
      });
      assertEquals(res.status, tc.status, tc.body.slice(0, 40));
      const json = await res.json() as Record<string, unknown>;
      assert(typeof json["e"] === "string" || typeof json["code"] === "string");
    }
  } finally {
    await sql.end();
  }
});

Deno.test("AC13 and AC23: delete removes device cascade and invalidates token", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const { token, id } = await register(hono);
    const me = await hono.request("/v1/me", {
      method: "DELETE",
      headers: { authorization: `Bearer ${token}` },
    });
    assertEquals(me.status, 204);
    assertEquals(
      await findDeviceByTokenHash(sql, await tokenHash(token)),
      null,
    );
    const consents =
      await sql`select count(*)::int as n from consents where device_id = ${id}`;
    assertEquals((consents[0] as { n: number }).n, 0);
    const retry = await hono.request("/v1/me", {
      method: "DELETE",
      headers: { authorization: `Bearer ${token}` },
    });
    assertEquals(retry.status, 401);
  } finally {
    await sql.end();
  }
});

Deno.test("AC23: database holds only token hashes", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const { token } = await register(hono);
    assert(!token.includes(" ") && token.startsWith("bm1_"));
    const rows = await sql`select token_hash from devices`;
    assertEquals(rows.length, 1);
    const stored = (rows[0] as { token_hash: Uint8Array }).token_hash;
    const expected = await tokenHash(token);
    assertEquals(stored.length, 32);
    assertEquals(stored.length, expected.length);
    for (let i = 0; i < expected.length; i++) {
      assertEquals(stored[i], expected[i]);
    }
  } finally {
    await sql.end();
  }
});

Deno.test("AC18: secure headers and CORS behavior", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const res = await hono.request("/v1/health");
    assertEquals(res.headers.get("x-content-type-options"), "nosniff");
    assertEquals(res.headers.get("referrer-policy"), "no-referrer");
    assertEquals(res.headers.get("access-control-allow-origin"), null);

    const allowed = await hono.request("/v1/health", {
      headers: { origin: "http://127.0.0.1:8080" },
    });
    assertEquals(
      allowed.headers.get("access-control-allow-origin"),
      "http://127.0.0.1:8080",
    );

    const denied = await hono.request("/v1/health", {
      headers: { origin: "https://evil.example" },
    });
    assertEquals(denied.headers.get("access-control-allow-origin"), null);

    const preflight = await hono.request("/v1/devices", {
      method: "OPTIONS",
      headers: {
        origin: "http://127.0.0.1:8080",
        "access-control-request-method": "POST",
        "access-control-request-headers": "content-type",
      },
    });
    assertEquals(preflight.status, 204);
    assertEquals(
      preflight.headers.get("access-control-allow-origin"),
      "http://127.0.0.1:8080",
    );
    assertEquals(
      preflight.headers.get("access-control-allow-methods"),
      "GET, POST, DELETE, OPTIONS",
    );
    assert(
      (preflight.headers.get("access-control-allow-headers") ?? "")
        .includes("if-none-match"),
    );

    const preflightDenied = await hono.request("/v1/devices", {
      method: "OPTIONS",
      headers: { origin: "https://evil.example" },
    });
    assertEquals(preflightDenied.status, 204);
    assertEquals(
      preflightDenied.headers.get("access-control-allow-origin"),
      null,
    );
  } finally {
    await sql.end();
  }
});

Deno.test("AC03: account routes define no trip or session id fields", async () => {
  const text = await Deno.readTextFile(
    new URL("../src/http/routes.ts", import.meta.url),
  );
  const lower = text.toLowerCase();
  assert(!lower.includes("trip_id") && !lower.includes("tripid"));
  assert(!lower.includes("session_id") && !lower.includes("sessionid"));
  const schemas = await Deno.readTextFile(
    new URL("../src/http/schemas.ts", import.meta.url),
  );
  assert(!schemas.toLowerCase().includes("trip"));
});

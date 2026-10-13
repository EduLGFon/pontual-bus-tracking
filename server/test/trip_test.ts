// T10 trip endpoint tests: AC02, AC07, AC09, AC10, AC14.
// HTTP-level tests run the real app in-process against test PostgreSQL.
// Engine behavior itself is covered in engine_test.ts. See PLAN.md 12.6.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb } from "../src/db/client.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";

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
    onVehicle: () => {},
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
  });
  return { sql, hono };
}

async function device(hono: ReturnType<typeof buildApp>): Promise<string> {
  const reg = await hono.request("/v1/devices", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assertEquals(reg.status, 201);
  const { token } = await reg.json() as { token: string };
  const consent = await hono.request("/v1/consents", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: '{"version":1}',
  });
  assertEquals(consent.status, 200);
  return token;
}

function startBody(line = 7): string {
  return JSON.stringify({
    line,
    lat: -18.72,
    lng: -39.85,
    acc: 10,
    bat: 80,
    chg: false,
  });
}

Deno.test("AC10: start requires current consent", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const reg = await hono.request("/v1/devices", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    const { token } = await reg.json() as { token: string };
    const noConsent = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(noConsent.status, 403);
    assertEquals(await noConsent.json(), { e: "consent" });

    await hono.request("/v1/consents", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: '{"version":1}',
    });
    const ok = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(ok.status, 201);
  } finally {
    await sql.end();
  }
});

Deno.test("AC10: old consent version rejected", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const token = await device(hono);
    await sql`insert into app_config (key, value) values ('consent_version', '2')`;
    const stale = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(stale.status, 403);
    assertEquals(await stale.json(), { e: "consent" });
  } finally {
    await sql.end();
  }
});

Deno.test("AC02: device B cannot affect device A", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const a = await device(hono);
    const b = await device(hono);
    const sa = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${a}`,
      },
      body: startBody(),
    });
    assertEquals(sa.status, 201);
    // B pings without its own trip: gone, and A is untouched.
    const pb = await hono.request("/v1/trip/ping", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${b}`,
      },
      body: JSON.stringify({
        seq: 1,
        lat: -18.72,
        lng: -39.85,
        spd: 8,
        hdg: 90,
        acc: 10,
        bat: 80,
        chg: false,
        role: "W",
      }),
    });
    assertEquals(pb.status, 404);
    // B ending nothing is idempotent, A still has its trip.
    const eb = await hono.request("/v1/trip", {
      method: "DELETE",
      headers: { authorization: `Bearer ${b}` },
    });
    assertEquals(eb.status, 204);
    const pa = await hono.request("/v1/trip/ping", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${a}`,
      },
      body: JSON.stringify({
        seq: 1,
        lat: -18.72,
        lng: -39.85,
        spd: 8,
        hdg: 90,
        acc: 10,
        bat: 80,
        chg: false,
        role: "W",
      }),
    });
    assertEquals(pa.status, 200);
  } finally {
    await sql.end();
  }
});

Deno.test("AC07: implausible fixes strike toward abuse", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const token = await device(hono);
    await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    // Accuracy 500 m is rejected; five strikes end the trip with abuse.
    // Rejected fixes never update lastSeenAt, so no waiting is needed.
    let last = "";
    for (let i = 1; i <= 5; i++) {
      const r = await hono.request("/v1/trip/ping", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          seq: i,
          lat: -18.72,
          lng: -39.85,
          spd: 8,
          hdg: 90,
          acc: 500,
          bat: 80,
          chg: false,
          role: "W",
        }),
      });
      last = JSON.stringify(await r.json());
    }
    assert(last.includes("abuse"), last);
  } finally {
    await sql.end();
  }
});

Deno.test("AC09: start quota and unknown line", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const token = await device(hono);
    const badLine = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(999),
    });
    assertEquals(badLine.status, 404);
    for (let i = 0; i < 6; i++) {
      const r = await hono.request("/v1/trip", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
        },
        body: startBody(),
      });
      assertEquals(r.status, 201);
    }
    const over = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(over.status, 429);
    assertEquals(await over.json(), { e: "quota" });
  } finally {
    await sql.end();
  }
});

Deno.test("AC14: kill switch stops writes with maint", async () => {
  await truncate();
  const { sql, hono } = app();
  try {
    const token = await device(hono);
    await sql`insert into app_config (key, value) values ('service_enabled', 'false')`;
    const stopped = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(stopped.status, 503);
    assertEquals(await stopped.json(), { e: "maint" });
    // Reads keep working.
    const health = await hono.request("/v1/health");
    assertEquals(health.status, 200);
  } finally {
    // Leave the shared dev database as found: the kill switch must
    // never leak into later runs (soak, manual trips). See T35 note.
    try {
      await sql`delete from app_config where key = 'service_enabled'`;
    } finally {
      await sql.end();
    }
  }
});

Deno.test("injected engine reaches the ping path: easy-publish promotes", async () => {
  // Regression: main.ts used to mutate one EngineConfig while the trip
  // routes built their own default, so TEST_EASY_PUBLISH never took
  // effect and stationary trips stayed W forever.
  await truncate();
  const sql = openDb(testDbUrl());
  const easy = defaultEngineConfig();
  easy.movingSpeedMps = 0;
  easy.movingTicksToPublish = 1;
  easy.accuracyMaxM = 500;
  const hono = buildApp({
    sql,
    store: createStore(),
    lines: registryResolver([{ id: 7, isActive: true, route: null }]),
    hub: new Hub(),
    followerJitterS: 0,
    onVehicle: () => {},
    trustCloudflare: false,
    allowedOrigins: [],
    engine: easy,
  });
  try {
    const token = await device(hono);
    const started = await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: startBody(),
    });
    assertEquals(started.status, 201);
    const ping = await hono.request("/v1/trip/ping", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      // Stationary and coarse (350 m): easy-publish counts every fix
      // as moving and relaxes the accuracy gate, so this still
      // promotes on the first ping.
      body: JSON.stringify({
        seq: 1,
        lat: -18.72,
        lng: -39.85,
        spd: 0,
        hdg: null,
        acc: 350,
        bat: 80,
        chg: false,
        role: "W",
      }),
    });
    assertEquals(ping.status, 200);
    // D45: the leader moving interval is 5 s.
    assertEquals(await ping.json(), { r: "L", n: 5 });
    const live = await hono.request("/v1/live");
    assertEquals(live.status, 200);
    assertEquals(await live.json(), [[7, 1]]);
  } finally {
    await sql.end();
  }
});

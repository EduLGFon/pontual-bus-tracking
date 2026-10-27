// T12 read endpoint tests: AC05 (read side) and AC06 (HTTP part).
// Vehicles snapshot with ETag, live lines, unknown lines, IP rate limits.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb } from "../src/db/client.ts";
import { applyPing, startTrip } from "../src/domain/ping.ts";
import {
  defaultEngineConfig,
  type EngineEvent,
  type Fix,
} from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";

const cfg = defaultEngineConfig();
const BUS = { lat: -18.72, lng: -39.85 };

function fix(over: Partial<Fix> = {}): Fix {
  return {
    lat: BUS.lat,
    lng: BUS.lng,
    speedMps: 8,
    heading: 90,
    accuracyM: 10,
    batteryPct: 80,
    charging: false,
    seq: 1,
    role: "W",
    ...over,
  };
}

function testDbUrl(): string {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  return url;
}

async function truncate(sql: ReturnType<typeof openDb>): Promise<void> {
  await sql`truncate devices, app_config restart identity cascade`;
}

function app() {
  const sql = openDb(testDbUrl());
  const store = createStore();
  const hono = buildApp({
    sql,
    store,
    lines: registryResolver([{ id: 7, isActive: true, route: null }]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: () => {},
    reportsEnabled: () => false,
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
  });
  return { sql, hono, store };
}

/** Seed one moving vehicle on line 7 at fake time base. */
function seedVehicle(
  store: ReturnType<typeof createStore>,
  base: number,
): void {
  const events: EngineEvent[] = [];
  startTrip(
    store,
    events,
    "d1",
    { id: 7, isActive: true },
    fix({ seq: 0 }),
    base,
    cfg,
  );
  applyPing(store, events, "d1", null, fix({ seq: 1 }), base + 5000, cfg, 0);
  applyPing(
    store,
    events,
    "d1",
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    base + 10000,
    cfg,
    0,
  );
}

Deno.test("vehicles snapshot shape, ETag, and cache headers", async () => {
  const { sql, hono, store } = app();
  try {
    seedVehicle(store, Date.now() - 10000);
    const res = await hono.request("/v1/lines/7/vehicles");
    assertEquals(res.status, 200);
    assertEquals(res.headers.get("cache-control"), "public, max-age=5");
    const etag = res.headers.get("etag");
    assert(etag && etag.length > 0);
    const body = await res.json() as { t: number; v: unknown[] };
    assert(typeof body.t === "number" && Array.isArray(body.v));

    const cached = await hono.request("/v1/lines/7/vehicles", {
      headers: { "if-none-match": etag },
    });
    assertEquals(cached.status, 304);
  } finally {
    await sql.end();
  }
});

Deno.test("unknown or inactive lines are 404", async () => {
  const { sql, hono } = app();
  try {
    assertEquals((await hono.request("/v1/lines/999/vehicles")).status, 404);
    assertEquals((await hono.request("/v1/lines/abc/vehicles")).status, 404);
  } finally {
    await sql.end();
  }
});

Deno.test("live lists only lines with vehicles", async () => {
  const { sql, hono, store } = app();
  try {
    const empty = await hono.request("/v1/live");
    assertEquals(empty.status, 200);
    assertEquals(await empty.json(), []);
    assertEquals(empty.headers.get("cache-control"), "public, max-age=10");

    seedVehicle(store, Date.now() - 10000);
    const live = await hono.request("/v1/live");
    assertEquals(await live.json(), [[7, 1]]);
  } finally {
    await sql.end();
  }
});

Deno.test("D30 arrivals carry timestamps only, 404 on unknown line", async () => {
  const { sql, hono, store } = app();
  try {
    assertEquals((await hono.request("/v1/lines/999/arrivals")).status, 404);
    const empty = await hono.request("/v1/lines/7/arrivals");
    assertEquals(empty.status, 200);
    assertEquals(
      empty.headers.get("cache-control"),
      "public, max-age=10",
    );
    const none = await empty.json() as {
      t: number;
      line: number;
      passages: number[];
      headwayMin: number | null;
      sampleSize: number;
    };
    assertEquals(none.sampleSize, 0);
    assertEquals(none.passages, []);

    seedVehicle(store, Date.now() - 10000);
    const res = await hono.request("/v1/lines/7/arrivals");
    assertEquals(res.status, 200);
    const body = await res.json() as typeof none;
    assertEquals(body.line, 7);
    assertEquals(body.sampleSize, 1);
    assertEquals(body.passages.length, 1);
    const text = JSON.stringify(body);
    assert(!text.includes("device"));
    assert(!text.includes("lat") && !text.includes("lng"));
  } finally {
    await sql.end();
  }
});

Deno.test("AC08: snapshot IP flood is rate limited", async () => {
  const { sql, hono } = app();
  try {
    let last = 200;
    for (let i = 0; i < 125; i++) {
      const r = await hono.request("/v1/live");
      last = r.status;
    }
    assertEquals(last, 429);
  } finally {
    await sql.end();
  }
});

Deno.test("AC08: device ping flood is contained", async () => {
  const { sql, hono } = app();
  // Order-independent: earlier files may leave kill-switch rows behind.
  await truncate(sql);
  try {
    const reg = await hono.request("/v1/devices", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    const { token } = await reg.json() as { token: string };
    await hono.request("/v1/consents", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: '{"version":2}',
    });
    await hono.request("/v1/trip", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        line: 7,
        lat: -18.72,
        lng: -39.85,
        acc: 10,
        bat: 80,
        chg: false,
      }),
    });
    // Rapid identical pings: duplicates return the current instruction.
    for (let i = 0; i < 4; i++) {
      await hono.request("/v1/trip/ping", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
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
    }
    // Fresh sequence numbers in a burst are ignored without strikes
    // (D29): a fast client stream must not end the trip. Ended trips
    // answer 404 gone, so every 200 here proves survival.
    for (let i = 2; i <= 8; i++) {
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
          acc: 10,
          bat: 80,
          chg: false,
          role: "W",
        }),
      });
      assertEquals(r.status, 200);
      const body = JSON.stringify(await r.json());
      assert(!body.includes('"e"'), body);
    }
  } finally {
    await sql.end();
  }
});

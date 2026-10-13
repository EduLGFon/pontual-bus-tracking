// T11 job tests: overlap guard, tick behavior, purge, config refresh,
// db health, and restart semantics (engine test 19 per PLAN.md 15.2).
import { assert, assertEquals } from "@std/assert";
import { openDb } from "../src/db/client.ts";
import { insertDevice } from "../src/db/devices.ts";
import { applyPing, isGone, startTrip } from "../src/domain/ping.ts";
import {
  defaultEngineConfig,
  type EngineEvent,
  type Fix,
} from "../src/domain/types.ts";
import { createStore } from "../src/state/store.ts";
import {
  runConfigRefresh,
  runDbHealth,
  runPurge,
  runTickGuarded,
} from "../src/jobs/jobs.ts";

const cfg = defaultEngineConfig();
const LINE = { id: 7, isActive: true };

function fix(over: Partial<Fix> = {}): Fix {
  return {
    lat: -18.72,
    lng: -39.85,
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

Deno.test("tick guard prevents overlap", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  const guard = { running: true };
  const out = runTickGuarded(guard, store, events, 0, cfg);
  assertEquals(out, { ran: false, changedLines: [] });
});

Deno.test("tick via guard ends timed-out trips", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  applyPing(store, events, "a", null, fix({ seq: 1 }), 5000, cfg, 0);
  applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 2, lat: -18.7199 }),
    10000,
    cfg,
    0,
  );
  assertEquals(store.vehicles.size, 1);
  const out = runTickGuarded({ running: false }, store, events, 611001, cfg);
  assertEquals(out.ran, true);
  assert(!store.trips.has("a"));
});

Deno.test("tick guard drains the scratch events buffer", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  applyPing(store, events, "a", null, fix({ seq: 1 }), 5000, cfg, 0);
  // Pre-tick the array holds start/attach events; the timeout below adds
  // a tripEnded event. None of it may survive the guarded tick, or ended
  // trips accumulate for the life of the process.
  runTickGuarded({ running: false }, store, events, 611001, cfg);
  assertEquals(events.length, 0);
});

Deno.test("purge removes expired devices", async () => {
  const sql = openDb(testDbUrl());
  try {
    await sql`truncate devices, app_config restart identity cascade`;
    await insertDevice(
      sql,
      crypto.getRandomValues(new Uint8Array(32)),
      new Date(Date.now() - 1000),
    );
    assertEquals(await runPurge(sql, new Date()), 1);
  } finally {
    await sql.end();
  }
});

Deno.test("config refresh reads overrides", async () => {
  const sql = openDb(testDbUrl());
  try {
    await sql`truncate devices, app_config restart identity cascade`;
    const base = await runConfigRefresh(sql);
    assertEquals(base.serviceEnabled, true);
    await sql`insert into app_config (key, value) values ('service_enabled', 'false')`;
    assertEquals((await runConfigRefresh(sql)).serviceEnabled, false);
  } finally {
    await sql.end();
  }
});

Deno.test("db health true when reachable", async () => {
  const sql = openDb(testDbUrl());
  try {
    assertEquals(await runDbHealth(sql), true);
  } finally {
    await sql.end();
  }
});

// 19. Restart: state empty, ping is gone, resume rebuilds.
Deno.test("19: restart drops state, resume rebuilds", () => {
  const events: EngineEvent[] = [];
  const fresh = createStore();
  const ping = applyPing(
    fresh,
    events,
    "a",
    null,
    fix({ seq: 5 }),
    999000,
    cfg,
    0,
  );
  assert(isGone(ping));
  const started = startTrip(
    fresh,
    events,
    "a",
    LINE,
    fix({ seq: 0 }),
    1000000,
    cfg,
  );
  assert(started.ok);
  const r1 = applyPing(
    fresh,
    events,
    "a",
    null,
    fix({ seq: 1 }),
    1005000,
    cfg,
    0,
  );
  assert(!isGone(r1));
  const r2 = applyPing(
    fresh,
    events,
    "a",
    null,
    fix({ seq: 2, lat: -18.7199 }),
    1010000,
    cfg,
    0,
  );
  assert(!isGone(r2) && r2.role === "L");
  assertEquals(fresh.vehicles.size, 1);
});

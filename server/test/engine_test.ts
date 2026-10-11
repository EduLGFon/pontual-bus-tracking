// Engine unit tests 1-18, 20-24 per PLAN.md 15.2. Pure, fake clock.
// Test 19 (restart) lands in T11 with the jobs.
import { assert, assertEquals } from "@std/assert";
import { createStore, membersOf } from "../src/state/store.ts";
import type { Store } from "../src/state/store.ts";
import {
  applyPing,
  endTrip,
  isGone,
  type PingOutcome,
  startTrip,
} from "../src/domain/ping.ts";
import { tick } from "../src/domain/tick.ts";
import { buildSnapshot } from "../src/domain/snapshot.ts";
import {
  defaultEngineConfig,
  type EngineEvent,
  type Fix,
} from "../src/domain/types.ts";

const cfg = defaultEngineConfig();
const LINE = { id: 7, isActive: true };
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

/** Start plus two moving pings. Creates a vehicle led by device at t0+10s. */
function movingTrip(
  store: Store,
  events: EngineEvent[],
  device: string,
  t0: number,
): void {
  startTrip(store, events, device, LINE, fix({ seq: 0 }), t0, cfg);
  const r1 = applyPing(
    store,
    events,
    device,
    null,
    fix({ seq: 1 }),
    t0 + 5000,
    cfg,
    0,
  );
  assert(!isGone(r1));
  const r2 = applyPing(
    store,
    events,
    device,
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    t0 + 10000,
    cfg,
    0,
  );
  assert(!isGone(r2));
}

/** Attach a second device at the vehicle's current spot, seconds later. */
function attachTrip(
  store: Store,
  events: EngineEvent[],
  device: string,
  t: number,
  over: Partial<Fix> = {},
) {
  startTrip(store, events, device, LINE, fix({ seq: 0, ...over }), t, cfg);
  return applyPing(
    store,
    events,
    device,
    null,
    fix({ seq: 1, ...over }),
    t + 3000,
    cfg,
    0,
  );
}

function vehicleId(store: Store): number {
  const ids = [...store.vehicles.keys()];
  assertEquals(ids.length, 1);
  return ids[0];
}

// 1. First moving trip creates a vehicle.
Deno.test("1: first moving trip creates a vehicle", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  assertEquals(store.vehicles.size, 1);
  assertEquals(store.vehicles.get(vehicleId(store))?.leaderDeviceId, "a");
});

// 2. A stopped lone trip never publishes.
Deno.test("2: stopped lone trip never publishes", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0, speedMps: 0 }), 0, cfg);
  for (let i = 1; i <= 4; i++) {
    const r = applyPing(
      store,
      events,
      "a",
      null,
      fix({ seq: i, speedMps: 0 }),
      i * 20000,
      cfg,
      0,
    );
    assert(!isGone(r) && r.role === "W");
  }
  assertEquals(store.vehicles.size, 0);
});

// 3. A second rider within tolerance attaches, even stopped.
Deno.test("3: second rider within tolerance attaches", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  const r = attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    speedMps: 0,
  });
  assert(!isGone(r) && r.role === "F");
  assertEquals(store.vehicles.size, 1);
});

// 4. A rider 600 m away does not attach.
Deno.test("4: rider 600 m away does not attach", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  startTrip(
    store,
    events,
    "b",
    LINE,
    fix({ seq: 0, lat: BUS.lat - 0.0054 }),
    12000,
    cfg,
  );
  const r = applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 1, lat: BUS.lat - 0.0054, speedMps: 8 }),
    15000,
    cfg,
    0,
  );
  assert(!isGone(r) && r.role === "W");
  assertEquals(store.trips.get("b")?.vehicleId, null);
});

// 5. Dead-reckoned follower fix 60 s later still attaches.
Deno.test("5: dead-reckoned follower attaches after 60 s", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  const predLng = v.lng +
    (8 * 60) / (111320 * Math.cos((v.lat * Math.PI) / 180));
  startTrip(
    store,
    events,
    "b",
    LINE,
    fix({ seq: 0, lat: v.lat, lng: predLng }),
    60000,
    cfg,
  );
  const r = applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 1, lat: v.lat, lng: predLng, speedMps: 8 }),
    70000,
    cfg,
    0,
  );
  assert(!isGone(r) && r.role === "F");
});

// 6. Detach after 2 incoherent fixes while the leader anchors the vehicle.
Deno.test("6: detach after 2 incoherent fixes", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const vv = store.vehicles.get(vehicleId(store))!;
  const p0Lat = vv.lat;
  const p0Lng = vv.lng;
  attachTrip(store, events, "b", 12000, { lat: p0Lat, lng: p0Lng });
  assert(store.trips.get("b")?.vehicleId !== null);
  const far1 = { lat: BUS.lat + 0.0001, lng: BUS.lng + 0.0024 };
  const far2 = { lat: BUS.lat + 0.0001, lng: BUS.lng + 0.0024 };
  applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 3, lat: p0Lat, lng: p0Lng }),
    20000,
    cfg,
    0,
  );
  applyPing(store, events, "b", null, fix({ seq: 2, ...far1 }), 25000, cfg, 0);
  applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 4, lat: p0Lat, lng: p0Lng }),
    30000,
    cfg,
    0,
  );
  const r = applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 3, ...far2 }),
    35000,
    cfg,
    0,
  );
  assert(!isGone(r) && r.role === "W");
  assertEquals(store.trips.get("b")?.vehicleId, null);
});

// 7. Two interleaved starts do not duplicate vehicles.
Deno.test("7: interleaved starts make one vehicle", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  startTrip(store, events, "b", LINE, fix({ seq: 0 }), 1000, cfg);
  applyPing(store, events, "a", null, fix({ seq: 1 }), 5000, cfg, 0);
  applyPing(store, events, "b", null, fix({ seq: 1 }), 6000, cfg, 0);
  applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    10000,
    cfg,
    0,
  );
  applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    11000,
    cfg,
    0,
  );
  assertEquals(store.vehicles.size, 1);
});

// 8. Charging beats higher battery.
Deno.test("8: charging beats higher battery", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    batteryPct: 50,
    charging: true,
  });
  store.trips.get("a")!.lastSeenAtMs = 296000;
  store.trips.get("b")!.lastSeenAtMs = 296000;
  v.lastElectAtMs = 0;
  tick(store, events, 301000, cfg);
  assertEquals(v.nextLeaderDeviceId, "b");
});

// 9. Battery below 15 pct ineligible unless alone.
Deno.test("9: low battery ineligible unless alone", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    batteryPct: 10,
  });
  store.trips.get("a")!.lastSeenAtMs = 296000;
  store.trips.get("b")!.lastSeenAtMs = 296000;
  v.lastElectAtMs = 0;
  tick(store, events, 301000, cfg);
  assert(v.nextLeaderDeviceId !== "b");

  const s2 = createStore();
  const e2: EngineEvent[] = [];
  startTrip(s2, e2, "solo", LINE, fix({ seq: 0, batteryPct: 10 }), 0, cfg);
  applyPing(
    s2,
    e2,
    "solo",
    null,
    fix({ seq: 1, batteryPct: 10 }),
    5000,
    cfg,
    0,
  );
  applyPing(
    s2,
    e2,
    "solo",
    null,
    fix({ seq: 2, batteryPct: 10, lat: BUS.lat + 0.0001 }),
    10000,
    cfg,
    0,
  );
  assertEquals(s2.vehicles.size, 1);
});

// 10. Tie goes to lowest ledS.
Deno.test("10: tie goes to lowest ledS", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, { lat: v.lat, lng: v.lng });
  store.trips.get("a")!.ledS = 100;
  store.trips.get("b")!.ledS = 5;
  store.trips.get("a")!.lastSeenAtMs = 296000;
  store.trips.get("b")!.lastSeenAtMs = 296000;
  v.lastElectAtMs = 0;
  tick(store, events, 301000, cfg);
  assertEquals(v.nextLeaderDeviceId, "b");
});

// 11. Dead leader hands over.
Deno.test("11: dead leader triggers handover", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    charging: true,
  });
  assertEquals(v.leaderDeviceId, "a");
  tick(store, events, 62000, cfg);
  assertEquals(v.leaderDeviceId, "b");
});

// 12. Two-phase hand-over.
Deno.test("12: two-phase hand-over has no gap", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    batteryPct: 60,
    charging: true,
  });
  store.trips.get("a")!.lastSeenAtMs = 296000;
  store.trips.get("b")!.lastSeenAtMs = 296000;
  v.lastElectAtMs = 0;
  tick(store, events, 301000, cfg);
  assertEquals(v.nextLeaderDeviceId, "b");
  const ra = applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 3 }),
    306000,
    cfg,
    0,
  );
  assert(!isGone(ra) && ra.role === "L");
  const rb = applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 2, batteryPct: 60, charging: true, role: "F" }),
    307000,
    cfg,
    0,
  );
  assert(!isGone(rb) && rb.role === "L" && rb.ackLeader !== true);
  assertEquals(v.leaderDeviceId, "a");
  const rb2 = applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 3, batteryPct: 60, charging: true, role: "L" }),
    312000,
    cfg,
    0,
  );
  assert(!isGone(rb2) && rb2.ackLeader === true);
  assertEquals(v.leaderDeviceId, "b");
});

// 13. Re-election at most every 300 s.
Deno.test("13: re-election throttled to 300 s", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  attachTrip(store, events, "b", 12000, {
    lat: v.lat,
    lng: v.lng,
    batteryPct: 60,
    charging: true,
  });
  store.trips.get("a")!.lastSeenAtMs = 145000;
  store.trips.get("b")!.lastSeenAtMs = 145000;
  v.lastElectAtMs = 50000;
  tick(store, events, 150000, cfg);
  assertEquals(v.nextLeaderDeviceId, null);
  store.trips.get("a")!.lastSeenAtMs = 346000;
  store.trips.get("b")!.lastSeenAtMs = 346000;
  tick(store, events, 351000, cfg);
  assertEquals(v.nextLeaderDeviceId, "b");
});

// 14. No idle end: a stationary trip (traffic jam, construction) survives.
Deno.test("14: stationary trip survives without an idle end", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0, speedMps: 0 }), 0, cfg);
  let end: string | undefined;
  for (let i = 1; i <= 16; i++) {
    const r = applyPing(
      store,
      events,
      "a",
      null,
      fix({ seq: i, speedMps: 0 }),
      i * 60000,
      cfg,
      0,
    );
    if (!isGone(r) && r.end) end = r.end;
  }
  assertEquals(end, undefined);
  assert(store.trips.has("a"));
});

// 15. Ping timeout ends the trip.
Deno.test("15: timeout ends a silent trip", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  tick(store, events, 611001, cfg);
  assert(!store.trips.has("a"));
  assert(events.some((e) => e.kind === "tripEnded" && e.reason === "timeout"));
});

// 16. Max 4 h ends the trip.
Deno.test("16: max duration ends the trip", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  store.trips.get("a")!.lastSeenAtMs = 14400000;
  tick(store, events, 14401000, cfg);
  assert(!store.trips.has("a"));
  assert(
    events.some((e) => e.kind === "tripEnded" && e.reason === "max_duration"),
  );
});

// 17. endTrip is idempotent; unknown ping is gone.
Deno.test("17: endTrip idempotent, unknown ping gone", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  endTrip(store, events, "a");
  endTrip(store, events, "a");
  const r = applyPing(store, events, "a", null, fix({ seq: 9 }), 20000, cfg, 0);
  assert(isGone(r));
});

// 18. Vehicle removed when no members alive.
Deno.test("18: vehicle reaped with no live members", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  assertEquals(store.vehicles.size, 1);
  tick(store, events, 311001, cfg);
  assertEquals(store.vehicles.size, 0);
  assert(store.trips.has("a"));
});

// 20. Snapshots only for changed lines.
Deno.test("20: tick reports only changed lines", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  const line9 = { id: 9, isActive: true };
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  applyPing(store, events, "a", null, fix({ seq: 1 }), 5000, cfg, 0);
  applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    10000,
    cfg,
    0,
  );
  startTrip(store, events, "b", line9, fix({ seq: 0 }), 1000, cfg);
  applyPing(store, events, "b", null, fix({ seq: 1 }), 6000, cfg, 0);
  applyPing(
    store,
    events,
    "b",
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    11000,
    cfg,
    0,
  );
  const quiet = tick(store, events, 11000, cfg);
  assertEquals(quiet.changedLines, []);
  endTrip(store, events, "a");
  const noisy = tick(store, events, 12000, cfg);
  assert(!noisy.changedLines.includes(9));
});

// 21. Snapshot shape and size.
Deno.test("21: snapshot shape is compact", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const snap = buildSnapshot(
    [...store.vehicles.values()],
    new Map([[1, membersOf(store, 1, 10000, cfg.memberAliveS)]]),
    7,
    10000,
    cfg.publishTtlS,
  );
  const bytes = new TextEncoder().encode(JSON.stringify(snap)).length;
  assert(snap.v.length === 1 && snap.v[0].length === 8);
  assert(bytes < 480, `snapshot too large: ${bytes}`);
});

// 22. Coordinates rounded to 5 decimals.
Deno.test("22: coordinates rounded to 5 decimals", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const snap = buildSnapshot(
    [...store.vehicles.values()],
    new Map([[1, membersOf(store, 1, 10000, cfg.memberAliveS)]]),
    7,
    10000,
    cfg.publishTtlS,
  );
  for (const row of snap.v) {
    for (const n of [row[1], row[2]]) {
      assertEquals(n, Math.round(n * 100000) / 100000);
    }
  }
});

// 23. Member count capped at 3.
Deno.test("23: member count capped at 3", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  const riders = ["b", "c", "d", "e"];
  riders.forEach((d, i) => {
    attachTrip(store, events, d, 12000 + i * 1000, { lat: v.lat, lng: v.lng });
  });
  const snap = buildSnapshot(
    [...store.vehicles.values()],
    new Map([[1, membersOf(store, 1, 120000, cfg.memberAliveS)]]),
    7,
    120000,
    cfg.publishTtlS,
  );
  assertEquals(snap.v[0][5], 3);
});

// 24. No device or trip ids leak.
Deno.test("24: snapshot leaks no ids", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const snap = buildSnapshot(
    [...store.vehicles.values()],
    new Map([[1, membersOf(store, 1, 10000, cfg.memberAliveS)]]),
    7,
    10000,
    cfg.publishTtlS,
  );
  const text = JSON.stringify(snap);
  assert(!text.includes("device"));
  assert(!text.includes("trip"));
});

// 25. Too-frequent pings are ignored without a strike (D29). A fast
// client stream (e.g. web watchPosition at ~1 Hz) must not end the
// trip; the server samples it at ~minPingIntervalS instead.
Deno.test("25: rapid pings ignored, trip survives", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  // 10 pings 1 s apart: all answered, none ends the trip.
  for (let i = 1; i <= 10; i++) {
    const r = applyPing(
      store,
      events,
      "a",
      null,
      fix({ seq: i, lat: BUS.lat + i * 0.00001 }),
      i * 1000,
      cfg,
      0,
    );
    assert(!isGone(r));
    if (!isGone(r)) assertEquals(r.end, undefined);
  }
  assertEquals(store.trips.get("a")?.strikes ?? -1, 0);
  // The trip still accepts a normally spaced ping afterwards.
  const r = applyPing(
    store,
    events,
    "a",
    null,
    fix({ seq: 11, lat: BUS.lat + 0.001 }),
    15000,
    cfg,
    0,
  );
  assert(!isGone(r));
});

// 26. Invalid fixes still strike toward abuse when sampled (AC07 at
// engine level): spaced-out bad pings end the trip.
Deno.test("26: spaced invalid pings still end abuse", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "a", LINE, fix({ seq: 0 }), 0, cfg);
  let last: PingOutcome = { role: "W", intervalS: 20 };
  // 5 s apart so each passes the rate gate and strikes on accuracy.
  for (let i = 1; i <= 5; i++) {
    last = applyPing(
      store,
      events,
      "a",
      null,
      fix({ seq: i, accuracyM: 500 }),
      i * 5000,
      cfg,
      0,
    );
    if (isGone(last)) break;
  }
  assert(!isGone(last));
  if (!isGone(last)) assertEquals(last.end, "abuse");
});

// 27. D30 pace starts at the creation fix speed.
Deno.test("27: vehicle pace starts at creation speed", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const v = store.vehicles.get(vehicleId(store))!;
  assertEquals(v.paceMps, 8);
});

// 28. D30 pace follows speed changes without keeping history.
Deno.test("28: vehicle pace adapts toward new speed", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  movingTrip(store, events, "a", 0);
  const id = vehicleId(store);
  // Slow driver takes over: repeated slow fixes drag pace down fast.
  for (let i = 3; i <= 8; i++) {
    applyPing(
      store,
      events,
      "a",
      null,
      fix({ seq: i, speedMps: 2, lat: BUS.lat + 0.0001 * i }),
      10000 + (i - 2) * 15000,
      cfg,
      0,
    );
  }
  const v = store.vehicles.get(id)!;
  assert(v.paceMps < 8 && v.paceMps >= 2, `pace=${v.paceMps}`);
  // Snapshot carries paceKmh as the additive 8th field.
  const snap = buildSnapshot(
    [...store.vehicles.values()],
    new Map([[id, membersOf(store, id, 200000, cfg.memberAliveS)]]),
    7,
    200000,
    cfg.publishTtlS,
  );
  assertEquals(snap.v[0].length, 8);
  assertEquals(snap.v[0][7], Math.round(v.paceMps * 3.6 * 10) / 10);
});

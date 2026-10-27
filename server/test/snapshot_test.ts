// Snapshot and membership index tests. Covers the single-pass grouping
// used by tick and snapshot generation, and the direct published-count
// path for /v1/live.
import { assert, assertEquals } from "@std/assert";
import { addVehicle, membersByVehicle } from "../src/domain/store.ts";
import type { Store } from "../src/domain/store.ts";
import type { Trip, Vehicle } from "../src/domain/types.ts";
import { createStore } from "../src/state/store.ts";
import { livePayload, snapshotRows } from "../src/state/snapshots.ts";

function trip(over: Partial<Trip>): Trip {
  return {
    deviceId: "a",
    tripKey: "k",
    lineId: 7,
    vehicleId: 1,
    startedAtMs: 0,
    lastSeenAtMs: 9000,
    seq: 1,
    lat: -18.72,
    lng: -39.85,
    speedMps: 8,
    heading: 90,
    accuracyM: 10,
    batteryPct: 80,
    charging: false,
    role: "L",
    movingTicks: 1,
    stillTicks: 0,
    coherenceFail: 0,
    strikes: 0,
    ledS: 0,
    offRoute: false,
    ...over,
  };
}

function vehicle(over: Partial<Vehicle>): Vehicle {
  return {
    id: 1,
    lineId: 7,
    lat: -18.72,
    lng: -39.85,
    heading: 90,
    speedMps: 8,
    paceMps: 8,
    fixAtMs: 9500,
    leaderDeviceId: "a",
    nextLeaderDeviceId: null,
    lastElectAtMs: 0,
    updatedAtMs: 9500,
    ...over,
  };
}

Deno.test("membersByVehicle groups alive trips once", () => {
  const store: Store = createStore();
  store.trips.set("a", trip({ deviceId: "a", vehicleId: 1 }));
  store.trips.set("b", trip({ deviceId: "b", vehicleId: 1 }));
  store.trips.set("c", trip({ deviceId: "c", vehicleId: 2 }));
  store.trips.set("stale", trip({ deviceId: "stale", lastSeenAtMs: 1000 }));
  store.trips.set("pending", trip({ deviceId: "pending", lastSeenAtMs: null }));

  const grouped = membersByVehicle(store, 10000, 5);
  assertEquals(grouped.get(1)?.map((t) => t.deviceId), ["a", "b"]);
  assertEquals(grouped.get(2)?.map((t) => t.deviceId), ["c"]);
  assertEquals(grouped.size, 2);
});

Deno.test("snapshotRows caps members from the grouped index", () => {
  const store: Store = createStore();
  addVehicle(store, vehicle({ id: 1 }));
  for (const deviceId of ["a", "b", "c", "d"]) {
    store.trips.set(deviceId, trip({ deviceId, vehicleId: 1 }));
  }
  const rows = snapshotRows(store, 7, 10000, 120, 300);
  assertEquals(rows.length, 1);
  assertEquals(rows[0][5], 3);
});

Deno.test("livePayload counts only published vehicles", () => {
  const store: Store = createStore();
  addVehicle(store, vehicle({ id: 1, lineId: 7, fixAtMs: 9500 }));
  addVehicle(store, vehicle({ id: 2, lineId: 7, fixAtMs: 9500 }));
  // Age 121 s exceeds the 120 s TTL.
  addVehicle(store, vehicle({ id: 3, lineId: 8, fixAtMs: 0 }));
  // Empty line id with no vehicle must not appear.
  store.byLine.set(9, new Set());

  const { body } = livePayload(store, 121000, 120);
  assertEquals(body, JSON.stringify([[7, 2]]));
  assert(!body.includes("lineId"));
});

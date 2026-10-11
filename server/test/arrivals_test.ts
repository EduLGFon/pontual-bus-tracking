// D30 arrivals tests. Pure, fake clock. No DB, no positions, no ids.
import { assert, assertEquals } from "@std/assert";
import { createStore } from "../src/state/store.ts";
import type { Store } from "../src/state/store.ts";
import { applyPing, startTrip } from "../src/domain/ping.ts";
import { tick } from "../src/domain/tick.ts";
import {
  arrivalsPayload,
  PASSAGE_MAX,
  PASSAGE_TTL_MS,
  prunePassages,
  recordPassage,
} from "../src/domain/arrivals.ts";
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

function movingTrip(store: Store, events: EngineEvent[], device: string) {
  startTrip(store, events, device, LINE, fix({ seq: 0 }), 0, cfg);
  applyPing(store, events, device, null, fix({ seq: 1 }), 5000, cfg, 0);
  applyPing(
    store,
    events,
    device,
    null,
    fix({ seq: 2, lat: BUS.lat + 0.0001 }),
    10000,
    cfg,
    0,
  );
}

Deno.test("arrivals: vehicle creation records one passage", () => {
  const store = createStore();
  movingTrip(store, [], "a");
  const p = arrivalsPayload(store, 7, 10000);
  assertEquals(p.sampleSize, 1);
  assertEquals(p.passages.length, 1);
  assertEquals(p.headwayMin, null);
});

Deno.test("arrivals: payload carries timestamps only", () => {
  const store = createStore();
  recordPassage(store, 7, 1000);
  recordPassage(store, 7, 70000);
  const p = arrivalsPayload(store, 7, 70000);
  const text = JSON.stringify(p);
  assert(!text.includes("device"));
  assert(!text.includes("lat") && !text.includes("lng"));
  assertEquals(p.line, 7);
  assertEquals(typeof p.t, "number");
});

Deno.test("arrivals: headway is the median gap in minutes", () => {
  const store = createStore();
  recordPassage(store, 7, 0);
  recordPassage(store, 7, 10 * 60000);
  recordPassage(store, 7, 30 * 60000);
  const p = arrivalsPayload(store, 7, 30 * 60000);
  assertEquals(p.headwayMin, 15);
});

Deno.test("arrivals: ring caps and TTL prunes", () => {
  const store = createStore();
  for (let i = 0; i < PASSAGE_MAX + 5; i++) recordPassage(store, 7, i * 1000);
  assert((store.passages.get(7) ?? []).length <= PASSAGE_MAX);
  prunePassages(store, PASSAGE_TTL_MS + 120000);
  assertEquals(store.passages.get(7), undefined);
  assertEquals(
    arrivalsPayload(store, 7, PASSAGE_TTL_MS + 120000).sampleSize,
    0,
  );
});

Deno.test("arrivals: tick prunes expired sightings", () => {
  const store = createStore();
  movingTrip(store, [], "a");
  assertEquals(arrivalsPayload(store, 7, 10000).sampleSize, 1);
  tick(store, [], PASSAGE_TTL_MS + 200000, cfg);
  assertEquals(
    arrivalsPayload(store, 7, PASSAGE_TTL_MS + 200000).sampleSize,
    0,
  );
});

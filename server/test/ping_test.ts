import { assert, assertEquals } from "@std/assert";
import { createStore } from "../src/state/store.ts";
import { applyPing, isGone, startTrip } from "../src/domain/ping.ts";
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

Deno.test("rate-limited ping returns rl and current instruction", () => {
  const store = createStore();
  const events: EngineEvent[] = [];
  startTrip(store, events, "dev", LINE, fix({ seq: 0 }), 0, cfg);
  const r1 = applyPing(
    store,
    events,
    "dev",
    null,
    fix({ seq: 1 }),
    5000,
    cfg,
    0,
  );
  assert(!isGone(r1));
  // Too soon: less than minPingIntervalS.
  const r2 = applyPing(
    store,
    events,
    "dev",
    null,
    fix({ seq: 2 }),
    5001,
    cfg,
    0,
  );
  assert(!isGone(r2));
  assertEquals(r2.rateLimited, true);
  assertEquals(typeof r2.role, "string");
  assertEquals(typeof r2.intervalS, "number");
});

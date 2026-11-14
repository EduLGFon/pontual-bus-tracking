// Deterministic ETA predictor tests: stopped-bus pace, sparse route progress,
// straight-line fallback and passed targets. No database.
import { assert, assertEquals } from "@std/assert";
import { predictEta } from "../src/learning/predictor.ts";
import type { LearningConsumer } from "../src/learning/consumer.ts";
import { defaultLearningConfig } from "../src/learning/types.ts";

const ORIGIN = { lat: -18.7, lng: -39.85 };
const M_PER_DEG_LAT = 111320;
const M_PER_DEG_LNG = 111320 * Math.cos((ORIGIN.lat * Math.PI) / 180);

function at(eastM: number, northM = 0) {
  return {
    lat: ORIGIN.lat + northM / M_PER_DEG_LAT,
    lng: ORIGIN.lng + eastM / M_PER_DEG_LNG,
  };
}

const noStats = {
  segmentStats: () => Promise.resolve(null),
  dwellStats: () => Promise.resolve(null),
} as unknown as LearningConsumer;

function stop(id: string, eastM: number) {
  return { id, ...at(eastM) };
}

Deno.test("stopped bus does not stretch a 1000 m ETA", async () => {
  const eta = await predictEta(
    noStats,
    defaultLearningConfig(),
    7,
    0,
    at(0).lat,
    at(0).lng,
    0.2,
    "target",
    [stop("target", 1000)],
    [at(0), at(1200)],
    1_000_000,
  );

  assert(
    Math.abs(eta.etaS - 167) <= 2,
    `ETA was ${eta.etaS}, expected about 167 s`,
  );
  assert(eta.etaS < 300, `ETA was ${eta.etaS}`);
  assert(eta.method === "learned", `method was ${eta.method}`);
});

Deno.test("no route returns a straight-line fallback, never zero or passed", async () => {
  const eta = await predictEta(
    noStats,
    defaultLearningConfig(),
    7,
    0,
    at(0).lat,
    at(0).lng,
    0.2,
    "target",
    [stop("target", 900)],
    [],
    1_000_000,
  );

  assertEquals(eta.etaS, 150);
  assertEquals(eta.confidence, "low");
  assertEquals(eta.sampleCount, 0);
  assertEquals(eta.method, "fallback_distance");
  assert(eta.etaS > 0);
});

Deno.test("moving bus uses segment and dwell stats", async () => {
  const calls: string[] = [];
  const consumer = {
    segmentStats: (
      _lineId: number,
      _direction: number,
      fromStop: string,
      toStop: string,
    ) => {
      calls.push(`${fromStop}->${toStop}`);
      if (fromStop === "a" && toStop === "b") {
        return Promise.resolve({ p50: 60, p90: 90, count: 4, distanceM: 300 });
      }
      if (fromStop === "b" && toStop === "c") {
        return Promise.resolve({ p50: 90, p90: 120, count: 5, distanceM: 500 });
      }
      return Promise.resolve(null);
    },
    dwellStats: (stopId: string) => {
      calls.push(`dwell:${stopId}`);
      if (stopId === "a") {
        return Promise.resolve({ p50: 10, p90: 15, count: 2 });
      }
      if (stopId === "b") {
        return Promise.resolve({ p50: 8, p90: 10, count: 3 });
      }
      return Promise.resolve(null);
    },
  } as unknown as LearningConsumer;

  const eta = await predictEta(
    consumer,
    defaultLearningConfig(),
    7,
    0,
    at(0).lat,
    at(0).lng,
    5,
    "c",
    [stop("a", 100), stop("b", 400), stop("c", 900)],
    [at(0), at(1000)],
    1_000_000,
  );

  // 20 s partial + 10 s dwell + 60 s segment + 8 s dwell + 90 s segment
  // adjusted to 100 s by the historical rate against the current pace.
  assertEquals(eta.etaS, 198);
  assertEquals(eta.sampleCount, 14);
  assertEquals(eta.confidence, "high");
  assertEquals(eta.method, "learned");
  assertEquals(calls, ["dwell:a", "a->b", "dwell:b", "b->c"]);
});

Deno.test("stopped bus applies historical stats at default speed", async () => {
  const consumer = {
    segmentStats: (
      _lineId: number,
      _direction: number,
      fromStop: string,
      toStop: string,
    ) => {
      if (fromStop === "a" && toStop === "b") {
        return Promise.resolve({ p50: 60, p90: 90, count: 4, distanceM: 300 });
      }
      if (fromStop === "b" && toStop === "c") {
        return Promise.resolve({ p50: 90, p90: 120, count: 5, distanceM: 500 });
      }
      return Promise.resolve(null);
    },
    dwellStats: () => Promise.resolve(null),
  } as unknown as LearningConsumer;

  const eta = await predictEta(
    consumer,
    defaultLearningConfig(),
    7,
    0,
    at(0).lat,
    at(0).lng,
    0.2,
    "c",
    [stop("a", 100), stop("b", 400), stop("c", 900)],
    [at(0), at(1000)],
    1_000_000,
  );

  // Stops are priced at their historic p50 with the factor measured against
  // the default 6 m/s, not against a 1 m/s pace floor.
  assert(
    Math.abs(eta.etaS - 190) <= 2,
    `ETA was ${eta.etaS}, expected about 190 s`,
  );
  assertEquals(eta.sampleCount, 9);
  assertEquals(eta.confidence, "medium");
  assertEquals(eta.method, "learned");
});

Deno.test("vehicle clearly past target with a route is passed", async () => {
  const eta = await predictEta(
    noStats,
    defaultLearningConfig(),
    7,
    0,
    at(800).lat,
    at(800).lng,
    5,
    "a",
    [stop("a", 300), stop("b", 600)],
    [at(0), at(1000)],
    1_000_000,
  );

  assertEquals(eta.etaS, 0);
  assertEquals(eta.confidence, "low");
  assertEquals(eta.method, "passed");
});

Deno.test("sparse route measures the partial leg to a stop between vertices", async () => {
  const eta = await predictEta(
    noStats,
    defaultLearningConfig(),
    7,
    0,
    at(100).lat,
    at(100).lng,
    0.3,
    "target",
    [stop("target", 1000)],
    [at(0), at(400), at(1200)],
    1_000_000,
  );

  // The target is 900 m along the route from the vehicle, not the 300 m
  // remainder of the nearest polyline segment.
  assertEquals(eta.etaS, 150);
  assertEquals(eta.method, "learned");
});

Deno.test("non-finite pace and invalid default speed stay finite", async () => {
  const eta = await predictEta(
    noStats,
    { ...defaultLearningConfig(), defaultSpeedMps: 0 },
    7,
    0,
    at(0).lat,
    at(0).lng,
    Number.NaN,
    "target",
    [stop("target", 600)],
    [],
    1_000_000,
  );

  assert(Number.isFinite(eta.etaS), `ETA was ${eta.etaS}`);
  assertEquals(eta.etaS, 100);
  assert(eta.etaS > 0);
});

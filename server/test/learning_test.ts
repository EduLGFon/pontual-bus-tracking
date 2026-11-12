// Learning consumer integration tests: consent gating, first-trip route
// publication, corridor accumulation and privacy gates. Non-DB cases use a
// stateful fake Sql tagged template that records queries; DB cases use
// TEST_DATABASE_URL.
import { assert, assertEquals } from "@std/assert";
import { decodePolyline } from "../src/domain/geo.ts";
import { openDb } from "../src/db/client.ts";
import { LearningConsumer } from "../src/learning/consumer.ts";
import { predictEta } from "../src/learning/predictor.ts";
import {
  defaultLearningConfig,
  type LearningConfig,
} from "../src/learning/types.ts";
import { fakeSql } from "./learning_fake_sql.ts";

const ORIGIN = { lat: -18.7, lng: -39.85 };
const M_PER_DEG_LAT = 111320;
const M_PER_DEG_LNG = 111320 * Math.cos((ORIGIN.lat * Math.PI) / 180);

function at(eastM: number, northM = 0) {
  return {
    lat: ORIGIN.lat + northM / M_PER_DEG_LAT,
    lng: ORIGIN.lng + eastM / M_PER_DEG_LNG,
  };
}

function eastOf(lat: number, lng: number): number {
  void lat;
  return (lng - ORIGIN.lng) * M_PER_DEG_LNG;
}

function testConfig(overrides: Partial<LearningConfig> = {}): LearningConfig {
  return {
    ...defaultLearningConfig(),
    trimEndsS: 0,
    minSampleSpacingM: 0,
    minSampleSpacingS: 0,
    corridorCellM: 50,
    ...overrides,
  };
}

function consumerFor(
  cfg: LearningConfig,
  privacyMode: "all" | "route_stops" = "all",
  sql = fakeSql().sql,
  clock: { now: number } = { now: 0 },
): LearningConsumer {
  return new LearningConsumer({
    sql,
    config: () => cfg,
    now: () => clock.now,
    privacyMode: () => privacyMode,
  });
}

interface TripPoint {
  tMs: number;
  lat: number;
  lng: number;
  speedMps: number;
}

function runTrip(
  consumer: LearningConsumer,
  lineId: number,
  tripKey: string,
  points: TripPoint[],
  opts = { consentVersion: 2 },
  clock: { now: number } = { now: 0 },
): void {
  const first = points[0];
  consumer.handle({
    kind: "tripStarted",
    lineId,
    tripKey,
    startedAtMs: first.tMs,
    lat: first.lat,
    lng: first.lng,
  }, opts);
  for (const p of points.slice(1)) {
    consumer.handle({
      kind: "fixAccepted",
      lineId,
      tripKey,
      atMs: p.tMs,
      lat: p.lat,
      lng: p.lng,
      speedMps: p.speedMps,
      heading: null,
      accuracyM: 5,
    }, opts);
  }
  clock.now = points[points.length - 1].tMs;
  consumer.handle({ kind: "tripEnded", lineId, tripKey, reason: "user" }, opts);
}

/** Moving points between two east offsets, every 50 m. */
function path(
  fromM: number,
  toM: number,
  startMs: number,
): TripPoint[] {
  const out: TripPoint[] = [];
  const dir = toM >= fromM ? 1 : -1;
  for (let d = fromM;; d += dir * 50) {
    const p = at(d);
    out.push({ tMs: startMs + out.length * 5000, ...p, speedMps: 10 });
    if (d === toM) break;
  }
  return out;
}

Deno.test("partial trips cover both halves of a line", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "all", sql, clock);

  for (let i = 0; i < 5; i++) {
    const half = i < 3 ? path(0, 400, 1_000_000 + i * 100_000) : path(
      400,
      800,
      1_000_000 + i * 100_000,
    );
    runTrip(consumer, 7, `trip-${i}`, half, { consentVersion: 2 }, clock);
  }
  await consumer.flush();

  const inserts = queries.filter((q) =>
    q.text.includes("insert into learned_routes")
  );
  // A route publishes after every contributing trip; the last one sees the
  // full corridor.
  const insert = inserts[inserts.length - 1];
  assert(insert, "expected a learned_routes insert");
  const polyline = insert.values[3] as string;
  const decoded = decodePolyline(polyline, 5);
  const east = decoded.map((p) => eastOf(p.lat, p.lng));
  assert(Math.min(...east) < 60, `polyline starts at ${Math.min(...east)}`);
  assert(Math.max(...east) > 740, `polyline ends at ${Math.max(...east)}`);
});

Deno.test("first contributing trip persists aggregates and publishes", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "all", sql, clock);

  runTrip(
    consumer,
    11,
    "short-trip",
    path(0, 150, 1_000_000),
    { consentVersion: 2 },
    clock,
  );
  await consumer.flush();

  assertEquals(
    queries.filter((q) => q.text.includes("insert into learning_route_cells"))
      .length,
    1,
  );
  assertEquals(
    queries.filter((q) => q.text.includes("insert into learning_route_edges"))
      .length,
    1,
  );
  assertEquals(
    queries.filter((q) => q.text.includes("insert into learning_route_state"))
      .length,
    1,
  );
  // There is no minimum trip count or corridor length gate: a short corridor
  // publishes on its first contributing trip.
  assertEquals(
    queries.filter((q) => q.text.includes("insert into learned_routes")).length,
    1,
  );
});

Deno.test("trip below minimum consent never contributes", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "all", sql, clock);

  for (let i = 0; i < 2; i++) {
    runTrip(
      consumer,
      7,
      `old-consent-${i}`,
      path(0, 400, 1_000_000 + i * 100_000),
      { consentVersion: 1 },
      clock,
    );
  }
  await consumer.flush();

  const writes = queries.filter((q) =>
    q.text.includes("insert into learning_route_cells") ||
    q.text.includes("insert into learning_route_edges") ||
    q.text.includes("insert into learning_route_state") ||
    q.text.includes("insert into learned_routes")
  );
  assertEquals(
    writes.map((q) => q.text),
    [],
  );
});

Deno.test("predictEta counts a one-pass segment despite the raw kMin", async () => {
  // The consumer read helpers already apply the effective privacy gate
  // (kMin 1 in mode "all"). Re-checking the raw kMin in the predictor
  // would discard valid one-pass rows and fall back to default speed.
  const consumer = {
    segmentStats: () =>
      Promise.resolve({ p50: 60, p90: 90, count: 1, distanceM: 300 }),
    dwellStats: () => Promise.resolve(null),
  } as unknown as LearningConsumer;
  // Vehicle at the route start, target past stop "a": the loop consults
  // segmentStats(a, b) and dwellStats(a).
  const stops = [
    { id: "a", ...at(100) },
    { id: "b", ...at(300) },
  ];
  const route = [at(0), at(300)];
  const eta = await predictEta(
    consumer,
    defaultLearningConfig(),
    7,
    0,
    at(0).lat,
    at(0).lng,
    5,
    "b",
    stops,
    route,
    1_000_000,
  );
  assert(eta.sampleCount >= 1, `sampleCount was ${eta.sampleCount}`);
});

function singleDwellTrip(
  consumer: LearningConsumer,
  lineId: number,
  clock: { now: number },
): void {
  const t0 = 2_000_000;
  const p = at(0);
  runTrip(
    consumer,
    lineId,
    "dwell-trip",
    [
      { tMs: t0, ...p, speedMps: 0 },
      { tMs: t0 + 5000, ...p, speedMps: 0 },
      { tMs: t0 + 10_000, ...p, speedMps: 0 },
    ],
    { consentVersion: 2 },
    clock,
  );
}

Deno.test("privacy mode all publishes a stop from one dwell pass", async () => {
  const cfg = testConfig({
    minStopPasses: 4,
    stopMinDistinctDays: 3,
    kMin: 5,
  });
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "all", sql, clock);
  singleDwellTrip(consumer, 8, clock);
  await consumer.flush();

  assertEquals(
    queries.filter((q) => q.text.includes("insert into learned_stops")).length,
    1,
  );
});

Deno.test("privacy mode route_stops withholds a single-pass stop", async () => {
  const cfg = testConfig({
    minStopPasses: 4,
    stopMinDistinctDays: 3,
    kMin: 5,
  });
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "route_stops", sql, clock);
  singleDwellTrip(consumer, 9, clock);
  await consumer.flush();

  assertEquals(
    queries.filter((q) => q.text.includes("insert into learned_stops")).length,
    0,
  );
});

Deno.test("terminus dwell suppression applies in mode all", async () => {
  const cfg = testConfig({
    minStopPasses: 4,
    stopMinDistinctDays: 3,
    kMin: 5,
  });
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, "all", sql, clock);
  const t0 = 2_000_000;
  runTrip(
    consumer,
    10,
    "terminus-trip",
    [
      { tMs: t0, ...at(0), speedMps: 0 },
      { tMs: t0 + 5000, ...at(0), speedMps: 0 },
      { tMs: t0 + 10_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 30_000, ...at(100), speedMps: 0 },
      { tMs: t0 + 35_000, ...at(100), speedMps: 0 },
      { tMs: t0 + 55_000, ...at(200), speedMps: 0 },
      { tMs: t0 + 60_000, ...at(200), speedMps: 0 },
    ],
    { consentVersion: 2 },
    clock,
  );
  await consumer.flush();

  const stops = queries.filter((q) =>
    q.text.includes("insert into learned_stops")
  );
  assertEquals(stops.length, 3);
  const dwells = queries.filter((q) =>
    q.text.includes("insert into stop_dwell_stats")
  );
  assertEquals(dwells.length, 1);

  // The only published dwell is the middle stop, never a terminus.
  const dwellStop = dwells[0].values[0] as string;
  const terminus = stops.filter((q) => {
    const east = eastOf(q.values[4] as number, q.values[5] as number);
    return east < 50 || east > 150;
  });
  assertEquals(terminus.length, 2);
  for (const q of terminus) {
    assert(q.values[0] !== dwellStop, "terminus dwell must be suppressed");
  }
});

const TEST_DB = Deno.env.get("TEST_DATABASE_URL");

Deno.test({
  name: "learnedRouteForLine picks the direction with more sample trips",
  ignore: !TEST_DB,
  fn: async () => {
    const sql = openDb(TEST_DB!);
    const lineId = 990_001;
    try {
      await sql`delete from learned_routes where line_id = ${lineId}`;
      const polyline = "_p~iF~ps|U_ulLnnqC";
      await sql`
        insert into learned_routes
          (line_id, direction, version, status, polyline, point_count,
           sample_trips, computed_at)
        values
          (${lineId}, 0, 1, 'active', ${polyline}, 2, 3, now()),
          (${lineId}, 1, 1, 'active', ${polyline}, 2, 7, now())
      `;
      const consumer = consumerFor(
        defaultLearningConfig(),
        "all",
        sql,
      );
      const route = await consumer.learnedRouteForLine(lineId);
      assertEquals(route?.dir, 1);
      assertEquals(route?.trips, 7);
    } finally {
      await sql`delete from learned_routes where line_id = ${lineId}`;
      await sql.end();
    }
  },
});

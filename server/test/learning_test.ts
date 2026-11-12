// Learning consumer integration tests: consent gating, first-trip route
// publication, corridor accumulation, DB-backed stop bins and cumulative
// dwell/travel stats. Non-DB cases use a stateful fake Sql tagged template
// that records queries; DB cases use TEST_DATABASE_URL.
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
  sql = fakeSql().sql,
  clock: { now: number } = { now: 0 },
): LearningConsumer {
  return new LearningConsumer({
    sql,
    config: () => cfg,
    now: () => clock.now,
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
  opts: { consentVersion: number; synthetic?: boolean } = { consentVersion: 2 },
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
    synthetic: opts.synthetic === true,
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
  const consumer = consumerFor(cfg, sql, clock);

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
  const consumer = consumerFor(cfg, sql, clock);

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
  // The ordinal projection always reads the persisted stops, even when this
  // trip created none.
  assert(
    queries.some((q) =>
      q.text.includes("select id, lat, lng from learned_stops")
    ),
  );
});

Deno.test("a synthetic trip contributes no aggregates", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);

  runTrip(
    consumer,
    12,
    "synthetic-trip",
    path(0, 400, 1_000_000),
    { consentVersion: 2, synthetic: true },
    clock,
  );
  await consumer.flush();

  for (
    const marker of [
      "insert into learning_route_cells",
      "insert into learning_route_edges",
      "insert into learning_route_state",
      "insert into learned_stops",
      "insert into learning_dwell_bins",
      "insert into learning_travel_bins",
      "insert into learned_routes",
    ]
  ) {
    assertEquals(
      queries.filter((q) => q.text.includes(marker)).length,
      0,
      marker,
    );
  }
});

Deno.test("trip below minimum consent never contributes", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);

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

Deno.test("predictEta counts a one-pass segment", async () => {
  // The consumer read helpers return any row with at least one sample, so a
  // one-pass segment is valid evidence rather than a fallback.
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

Deno.test("a single dwell creates a stop and a dwell stat with count 1", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);
  singleDwellTrip(consumer, 8, clock);
  await consumer.flush();

  assertEquals(
    queries.filter((q) => q.text.includes("insert into learned_stops")).length,
    1,
  );
  assertEquals(
    queries.filter((q) => q.text.includes("insert into learning_dwell_bins"))
      .length,
    1,
  );
  const stats = queries.filter((q) =>
    q.text.includes("insert into stop_dwell_stats")
  );
  assertEquals(stats.length, 1);
  assertEquals(stats[0].values[3], 1);
});

/** Two dwells at 0 m and 100 m, 10 s apart. */
function segmentTrip(
  consumer: LearningConsumer,
  lineId: number,
  t0: number,
  tripKey: string,
  clock: { now: number },
): void {
  runTrip(
    consumer,
    lineId,
    tripKey,
    [
      { tMs: t0, ...at(0), speedMps: 0 },
      { tMs: t0 + 5000, ...at(0), speedMps: 0 },
      { tMs: t0 + 10_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 20_000, ...at(100), speedMps: 0 },
      { tMs: t0 + 25_000, ...at(100), speedMps: 0 },
    ],
    { consentVersion: 2 },
    clock,
  );
}

Deno.test("a single segment creates a travel stat with count 1", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);
  segmentTrip(consumer, 10, 2_000_000, "segment-trip", clock);
  await consumer.flush();

  assertEquals(
    queries.filter((q) => q.text.includes("insert into learned_stops")).length,
    2,
  );
  // Ordinals are projected from the stops persisted in PostgreSQL, not from
  // a process-local cluster map.
  assert(
    queries.some((q) =>
      q.text.includes("select id, lat, lng from learned_stops")
    ),
  );
  assert(
    queries.some((q) => q.text.includes("update learned_stops set ordinal")),
  );
  const travel = queries.filter((q) =>
    q.text.includes("insert into learning_travel_bins")
  );
  assertEquals(travel.length, 1);
  const stats = queries.filter((q) =>
    q.text.includes("insert into segment_stats")
  );
  assertEquals(stats.length, 1);
  assertEquals(stats[0].values[6], 1);
  assert(
    (stats[0].values[9] as number) > 90 &&
      (stats[0].values[9] as number) < 110,
    `distance was ${stats[0].values[9]}`,
  );
  // The read helper serves that one-sample row instead of hiding it.
  const b = travel[0].values;
  const seg = await consumer.segmentStats(
    b[0] as number,
    b[1] as number,
    b[2] as string,
    b[3] as string,
    b[4] as number,
    b[5] as number,
  );
  assertEquals(seg?.count, 1);
});

Deno.test("two dwells in one bucket accumulate count and a cumulative p50", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);
  const t0 = 2_000_000;

  // 5 s dwell, then a 15 s dwell in the same 15-minute bucket and day. The
  // second recompute must read both bins, not replace the first batch.
  singleDwellTrip(consumer, 11, clock);
  runTrip(
    consumer,
    11,
    "long-dwell",
    [
      { tMs: t0 + 60_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 65_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 70_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 75_000, ...at(0), speedMps: 0 },
      { tMs: t0 + 80_000, ...at(0), speedMps: 0 },
    ],
    { consentVersion: 2 },
    clock,
  );
  await consumer.flush();

  const stats = queries.filter((q) =>
    q.text.includes("insert into stop_dwell_stats")
  );
  assertEquals(stats.length, 2);
  const last = stats[1];
  assertEquals(last.values[3], 2);
  assertEquals(last.values[4], 5);
  assertEquals(last.values[5], 15);
});

Deno.test("a trip crossing midnight buckets each segment by its own timestamp", async () => {
  const cfg = testConfig();
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);
  // 2026-01-01T02:59:50Z is 2025-12-31 23:59:50 in America/Sao_Paulo.
  const base = Date.UTC(2026, 0, 1, 2, 59, 50);

  runTrip(
    consumer,
    12,
    "midnight-trip",
    [
      { tMs: base, ...at(0), speedMps: 0 },
      { tMs: base + 5000, ...at(0), speedMps: 0 },
      { tMs: base + 10_000, ...at(0), speedMps: 0 },
      { tMs: base + 30_000, ...at(100), speedMps: 0 },
      { tMs: base + 35_000, ...at(100), speedMps: 0 },
    ],
    { consentVersion: 2 },
    clock,
  );
  await consumer.flush();

  const dwells = queries.filter((q) =>
    q.text.includes("insert into learning_dwell_bins")
  );
  assertEquals(
    dwells.map((q) => [q.values[1], q.values[2]]),
    [[95, 3], [0, 4]],
  );
  const travel = queries.filter((q) =>
    q.text.includes("insert into learning_travel_bins")
  );
  assertEquals(travel.length, 1);
  // The segment is bucketed at the destination arrival (after local midnight).
  assertEquals(travel[0].values[4], 0);
  assertEquals(travel[0].values[5], 4);
});

Deno.test("a short trip keeps its middle dwell despite the trim", async () => {
  // 120 s trim would discard a 90 s trip entirely; the proportional trim
  // (10% per end) keeps the middle dwell and contributes it.
  const cfg = testConfig({ trimEndsS: 120 });
  const { sql, queries } = fakeSql();
  const clock = { now: 0 };
  const consumer = consumerFor(cfg, sql, clock);
  const t0 = 3_000_000;
  const points: TripPoint[] = [];
  for (let i = 0; i <= 4; i++) {
    points.push({ tMs: t0 + i * 5000, ...at(i * 20), speedMps: 10 });
  }
  for (let i = 5; i <= 12; i++) {
    points.push({ tMs: t0 + i * 5000, ...at(100), speedMps: 0 });
  }
  for (let i = 13; i <= 18; i++) {
    points.push({
      tMs: t0 + i * 5000,
      ...at(100 + (i - 12) * 50),
      speedMps: 10,
    });
  }
  runTrip(consumer, 13, "short-trip", points, { consentVersion: 2 }, clock);
  await consumer.flush();

  assert(
    queries.some((q) => q.text.includes("insert into learned_stops")),
    "expected a stop from the short trip",
  );
  assert(
    queries.some((q) => q.text.includes("insert into learning_dwell_bins")),
    "expected a dwell bin from the short trip",
  );
  assert(
    queries.some((q) => q.text.includes("insert into stop_dwell_stats")),
    "expected a dwell stat from the short trip",
  );
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
      const consumer = consumerFor(defaultLearningConfig(), sql);
      const route = await consumer.learnedRouteForLine(lineId);
      assertEquals(route?.dir, 1);
      assertEquals(route?.trips, 7);
    } finally {
      await sql`delete from learned_routes where line_id = ${lineId}`;
      await sql.end();
    }
  },
});

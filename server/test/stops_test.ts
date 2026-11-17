// Global learned-stop read endpoints and pure grouping tests. No PostgreSQL.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import type { LineRecord } from "../src/data/lines.ts";
import { groupStops, stopMergeRadiusM } from "../src/domain/stops.ts";
import type { StopMember } from "../src/domain/stops.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import type { Vehicle } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { createStore } from "../src/state/store.ts";
import type { Store } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";
import { defaultLearningConfig } from "../src/learning/types.ts";
import type { LearningConsumer } from "../src/learning/consumer.ts";

const ORIGIN = { lat: -18.72, lng: -39.85 };
const M_PER_DEG_LAT = 111320;
const M_PER_DEG_LNG = 111320 * Math.cos((ORIGIN.lat * Math.PI) / 180);

function at(eastM: number, northM = 0) {
  return {
    lat: ORIGIN.lat + northM / M_PER_DEG_LAT,
    lng: ORIGIN.lng + eastM / M_PER_DEG_LNG,
  };
}

function member(
  id: string,
  lineId: number,
  direction: number,
  pos = ORIGIN,
  passes = 1,
  radiusM = 30,
): StopMember {
  return { id, lineId, direction, lat: pos.lat, lng: pos.lng, radiusM, passes };
}

type FakeStop = {
  id: string;
  ordinal: number;
  lat: number;
  lng: number;
  radiusM: number;
  passes: number;
};

type FakeGroup = { lineId: number; direction: number; stops: FakeStop[] };

type FakeRoute = {
  dir: number;
  polyline: string;
  version: number;
  trips: number;
  computedAt: string;
};

type FakeOptions = {
  enabled?: boolean;
  groups?: FakeGroup[];
  routes?: Map<number, FakeRoute>;
  stopsByLineDir?: Map<string, FakeStop[]>;
};

const STRONG: FakeStop = {
  id: "stop-strong",
  ordinal: 1,
  lat: ORIGIN.lat,
  lng: ORIGIN.lng,
  radiusM: 30,
  passes: 12,
};
const WEAK: FakeStop = {
  id: "stop-weak",
  ordinal: 2,
  lat: ORIGIN.lat + 0.0001,
  lng: ORIGIN.lng + 0.0001,
  radiusM: 20,
  passes: 5,
};

function defaultGroups(): FakeGroup[] {
  return [
    { lineId: 66, direction: 0, stops: [STRONG] },
    { lineId: 66, direction: 1, stops: [WEAK] },
  ];
}

function defaultStopsByLineDir(): Map<string, FakeStop[]> {
  return new Map([
    ["66:0", [STRONG]],
    ["66:1", [WEAK]],
  ]);
}

function makeFakeLearning(opts: FakeOptions = {}) {
  const enabled = opts.enabled ?? true;
  const groups = opts.groups ?? defaultGroups();
  const routes = opts.routes ?? new Map<number, FakeRoute>();
  const stopsByLineDir = opts.stopsByLineDir ?? defaultStopsByLineDir();
  let calls = 0;
  const learning = {
    isEnabled: () => enabled,
    allLearnedStops: () => {
      calls += 1;
      return Promise.resolve(enabled ? groups : []);
    },
    learnedRouteForLine: (lineId: number) =>
      Promise.resolve(routes.get(lineId) ?? null),
    learnedStopsForLine: (lineId: number, dir: number) =>
      Promise.resolve(stopsByLineDir.get(`${lineId}:${dir}`) ?? []),
    segmentStats: () => Promise.resolve(null),
    dwellStats: () => Promise.resolve(null),
    configSnapshot: () => defaultLearningConfig(),
  };
  return {
    learning: learning as unknown as LearningConsumer,
    calls: () => calls,
  };
}

const LINE_66: LineRecord = {
  id: 66,
  code: "66-centro-ifes-ufes",
  isActive: true,
  route: null,
};
const LINE_77: LineRecord = {
  id: 77,
  code: "77-centro-ifes-ufes",
  isActive: true,
  route: null,
};

function vehicle(
  id: number,
  lineId: number,
  pos = ORIGIN,
): Vehicle {
  return {
    id,
    lineId,
    lat: pos.lat,
    lng: pos.lng,
    heading: null,
    speedMps: 8,
    paceMps: 8,
    fixAtMs: 0,
    leaderDeviceId: null,
    nextLeaderDeviceId: null,
    lastElectAtMs: 0,
    updatedAtMs: 0,
  };
}

function buildTestApp(opts: {
  learning: LearningConsumer;
  lines?: LineRecord[];
  store?: Store;
}) {
  return buildApp({
    sql: null,
    store: opts.store ?? createStore(),
    lines: registryResolver(opts.lines ?? [LINE_66]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: () => {},
    reportsEnabled: () => false,
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
    learning: opts.learning,
  });
}

function collectKeys(value: unknown, out = new Set<string>()): Set<string> {
  if (Array.isArray(value)) {
    for (const item of value) collectKeys(item, out);
  } else if (value && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      out.add(key);
      collectKeys(child, out);
    }
  }
  return out;
}

function assertKeys(value: unknown, expected: string[]): void {
  assertEquals([...collectKeys(value)].sort(), [...expected].sort());
}

Deno.test("groupStops merges same physical stop across lines", () => {
  const groups = groupStops([
    member("b", 2, 1, ORIGIN, 5, 20),
    member("a", 1, 0, ORIGIN, 12, 30),
  ], stopMergeRadiusM);
  assertEquals(groups.length, 1);
  assertEquals(groups[0].id, "a");
  assertEquals(groups[0].radiusM, 30);
  assertEquals(groups[0].passes, 12);
  assertEquals(groups[0].members.length, 2);
});

Deno.test("groupStops keeps distant stops separate", () => {
  const groups = groupStops([
    member("a", 1, 0, at(0), 12),
    member("b", 2, 1, at(100), 5),
  ], stopMergeRadiusM);
  assertEquals(groups.length, 2);
});

Deno.test("groupStops canonical id is smallest member id, not passes", () => {
  const groups = groupStops([
    member("a", 1, 0, ORIGIN, 2),
    member("z", 2, 1, ORIGIN, 9),
  ], stopMergeRadiusM);
  assertEquals(groups.length, 1);
  assertEquals(groups[0].id, "a");
  // The stronger member still anchors geometry.
  assertEquals(groups[0].passes, 9);
});

Deno.test("groupStops preserves member line and direction", () => {
  const groups = groupStops([
    member("a", 1, 0, ORIGIN, 12),
    member("b", 2, 1, ORIGIN, 5),
  ], stopMergeRadiusM);
  const ids = groups[0].members.map((m) =>
    `${m.lineId}:${m.direction}:${m.id}`
  );
  assert(ids.includes("1:0:a"));
  assert(ids.includes("2:1:b"));
});

Deno.test("groupStops handles empty input", () => {
  assertEquals(groupStops([], stopMergeRadiusM), []);
});

Deno.test("groupStops does not throw on non-finite coords", () => {
  const invalid = {
    ...member("x", 1, 0, ORIGIN, 1),
    lat: Number.NaN,
  };
  assertEquals(groupStops([invalid], stopMergeRadiusM), []);
});

Deno.test("groupStops merge radius is inclusive at 50 m", () => {
  const groups = groupStops([
    member("a", 1, 0, at(0), 10),
    member("b", 1, 1, at(49), 5),
    member("c", 1, 0, at(50), 4),
    member("d", 1, 1, at(51), 3),
  ], stopMergeRadiusM);
  assertEquals(groups.length, 2);
  assertEquals(
    groups[0].members.map((m) => m.id).sort(),
    ["a", "b", "c"],
  );
  assertEquals(groups[1].id, "d");
});

Deno.test("groupStops handles 2,000 well-separated stops", () => {
  const stops: StopMember[] = [];
  for (let i = 0; i < 2000; i++) {
    const northM = Math.floor(i / 50) * 100;
    const eastM = (i % 50) * 100;
    stops.push(member(`s${i}`, 1, 0, at(eastM, northM), 1));
  }
  const groups = groupStops(stops, stopMergeRadiusM);
  assertEquals(groups.length, 2000);
});

Deno.test("groupStops is deterministic on equal passes", () => {
  const a = member("a", 2, 1, at(0), 5);
  const b = member("b", 1, 0, at(0), 5);
  const c = member("c", 1, 0, at(200), 5);
  const forward = groupStops([a, b, c], stopMergeRadiusM);
  const reverse = groupStops([c, b, a], stopMergeRadiusM);
  assertEquals(forward, reverse);
  assertEquals(forward[0].id, "a");
});

Deno.test("/v1/stops returns merged shape and cache header", async () => {
  const fake = makeFakeLearning();
  const hono = buildTestApp({ learning: fake.learning });
  const res = await hono.request("/v1/stops");
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("cache-control"), "public, max-age=300");
  const body = await res.json() as {
    v: number;
    stops: Array<{
      id: string;
      lat: number;
      lng: number;
      r: number;
      n: number;
      lines: Array<{ l: number; d: number; s: string }>;
    }>;
  };
  assertEquals(body.v, 1);
  assertEquals(body.stops.length, 1);
  const stop = body.stops[0];
  assertEquals(stop.id, "stop-strong");
  assertEquals(stop.r, 30);
  assertEquals(stop.n, 12);
  assertEquals(stop.lines.length, 2);
  assertKeys(body, [
    "v",
    "stops",
    "id",
    "lat",
    "lng",
    "r",
    "n",
    "lines",
    "l",
    "d",
    "s",
  ]);
});

Deno.test("/v1/stops filters inactive lines", async () => {
  const active = { ...STRONG, id: "z-active" };
  const inactive = { ...STRONG, id: "a-inactive" };
  const fake = makeFakeLearning({
    groups: [
      { lineId: 66, direction: 0, stops: [active] },
      { lineId: 77, direction: 0, stops: [inactive] },
    ],
  });
  const hono = buildTestApp({
    learning: fake.learning,
    lines: [LINE_66, { ...LINE_77, isActive: false }],
  });
  const res = await hono.request("/v1/stops");
  const body = await res.json() as {
    stops: Array<{ id: string; lines: Array<{ l: number }> }>;
  };
  assertEquals(body.stops.length, 1);
  assertEquals(body.stops[0].id, "z-active");
  assertEquals(body.stops[0].lines.map((l) => l.l), [66]);
});

Deno.test("/v1/stops returns 404 when learning disabled", async () => {
  const fake = makeFakeLearning({ enabled: false });
  const hono = buildTestApp({ learning: fake.learning });
  const res = await hono.request("/v1/stops");
  assertEquals(res.status, 404);
  const body = await res.json() as { e: string };
  assertEquals(body.e, "not_found");
});

Deno.test("stop grouping is cached across both endpoints", async () => {
  const fake = makeFakeLearning();
  const hono = buildTestApp({ learning: fake.learning });
  assertEquals((await hono.request("/v1/stops")).status, 200);
  assertEquals((await hono.request("/v1/stops")).status, 200);
  assertEquals(fake.calls(), 1);
  assertEquals(
    (await hono.request("/v1/stops/stop-strong/arrivals")).status,
    200,
  );
  assertEquals(fake.calls(), 1);
});

Deno.test("/v1/stops/:id/arrivals returns 200 with expected item", async () => {
  const fake = makeFakeLearning();
  const store = createStore();
  store.vehicles.set(1, vehicle(1, 66));
  const hono = buildTestApp({ learning: fake.learning, store });
  const listRes = await hono.request("/v1/stops");
  const listBody = await listRes.json() as {
    stops: Array<{ id: string }>;
  };
  const id = listBody.stops[0].id;

  const res = await hono.request(`/v1/stops/${id}/arrivals`);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("cache-control"), "public, max-age=10");
  const body = await res.json() as {
    id: string;
    now: number;
    items: Array<{
      line: number;
      code: string;
      vehicle: number;
      eta_s: number;
      conf: string;
      n: number;
      m: string;
    }>;
  };
  assertEquals(body.id, id);
  assert(typeof body.now === "number");
  assertEquals(body.items.length, 1);
  const item = body.items[0];
  assertEquals(item.line, 66);
  assertEquals(item.code, "66-centro-ifes-ufes");
  assertEquals(item.vehicle, 1);
  assert(typeof item.eta_s === "number");
  assert(typeof item.m === "string");
  assertKeys(body, [
    "id",
    "now",
    "items",
    "line",
    "code",
    "vehicle",
    "eta_s",
    "conf",
    "n",
    "m",
  ]);
});

Deno.test("/v1/stops/:id/arrivals returns 404 for unknown stop", async () => {
  const fake = makeFakeLearning();
  const hono = buildTestApp({ learning: fake.learning });
  const res = await hono.request("/v1/stops/does-not-exist/arrivals");
  assertEquals(res.status, 404);
  const body = await res.json() as { e: string };
  assertEquals(body.e, "not_found");
});

Deno.test("/v1/stops/:id/arrivals returns 404 when learning disabled", async () => {
  const fake = makeFakeLearning({ enabled: false });
  const hono = buildTestApp({ learning: fake.learning });
  const res = await hono.request("/v1/stops/stop-strong/arrivals");
  assertEquals(res.status, 404);
  const body = await res.json() as { e: string };
  assertEquals(body.e, "not_found");
});

Deno.test("cross-line group yields one item per vehicle per served line", async () => {
  const stop66 = { ...STRONG, id: "a", passes: 5 };
  const stop77 = { ...STRONG, id: "b", passes: 4 };
  const fake = makeFakeLearning({
    groups: [
      { lineId: 66, direction: 0, stops: [stop66] },
      { lineId: 77, direction: 0, stops: [stop77] },
    ],
    stopsByLineDir: new Map([
      ["66:0", [stop66]],
      ["77:0", [stop77]],
    ]),
  });
  const store = createStore();
  store.vehicles.set(1, vehicle(1, 66));
  store.vehicles.set(2, vehicle(2, 77));
  const hono = buildTestApp({
    learning: fake.learning,
    lines: [LINE_66, LINE_77],
    store,
  });
  const listBody = await (await hono.request("/v1/stops")).json() as {
    stops: Array<{ id: string }>;
  };
  const body = await (await hono.request(
    `/v1/stops/${listBody.stops[0].id}/arrivals`,
  )).json() as {
    items: Array<{ line: number; vehicle: number }>;
  };
  assertEquals(body.items.length, 2);
  const pairs = body.items.map((i) => `${i.line}:${i.vehicle}`).sort();
  assertEquals(pairs, ["66:1", "77:2"]);
});

Deno.test("opposite-direction-only line yields no item", async () => {
  const stop66 = { ...STRONG, id: "a", passes: 5 };
  const stop77 = { ...STRONG, id: "b", passes: 4 };
  const fake = makeFakeLearning({
    groups: [
      { lineId: 66, direction: 0, stops: [stop66] },
      { lineId: 77, direction: 1, stops: [stop77] },
    ],
    // Force line 77 to serve direction 0 while its only group member is 1.
    routes: new Map([[
      77,
      {
        dir: 0,
        polyline: "",
        version: 1,
        trips: 0,
        computedAt: "",
      },
    ]]),
    stopsByLineDir: new Map([
      ["66:0", [stop66]],
      ["77:0", []],
      ["77:1", [stop77]],
    ]),
  });
  const store = createStore();
  store.vehicles.set(1, vehicle(1, 66));
  store.vehicles.set(2, vehicle(2, 77));
  const hono = buildTestApp({
    learning: fake.learning,
    lines: [LINE_66, LINE_77],
    store,
  });
  const listBody = await (await hono.request("/v1/stops")).json() as {
    stops: Array<{ id: string }>;
  };
  const body = await (await hono.request(
    `/v1/stops/${listBody.stops[0].id}/arrivals`,
  )).json() as {
    items: Array<{ line: number }>;
  };
  assertEquals(body.items.length, 1);
  assertEquals(body.items[0].line, 66);
});

Deno.test("/v1/stops is rate limited after 60 requests per IP", async () => {
  const fake = makeFakeLearning();
  const hono = buildTestApp({ learning: fake.learning });
  const headers = { "x-socket-addr": "203.0.113.7" };
  const statuses: number[] = [];
  for (let i = 0; i < 61; i++) {
    const res = await hono.request("/v1/stops", { headers });
    statuses.push(res.status);
  }
  assertEquals(statuses[59], 200);
  assertEquals(statuses[60], 429);
});

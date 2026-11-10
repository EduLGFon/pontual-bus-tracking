// Corridor accumulation tests. Pure geometry: no DB, clock, or network.
import { assert, assertEquals, assertNotEquals } from "@std/assert";
import {
  addTrip,
  assignOrdinals,
  buildChain,
  coverageScore,
  newCorridorAcc,
  type Pt,
} from "../src/learning/corridor.ts";

const ORIGIN: Pt = { lat: -18.7, lng: -39.85 };
const CELL_M = 10;
const CONFIG = { cellM: CELL_M, minEdgeWeight: 1, minCells: 3 };
const M_PER_DEG_LAT = 111320;
const M_PER_DEG_LNG = 111320 * Math.cos((ORIGIN.lat * Math.PI) / 180);

/** Point at the given offset in metres east and north of the origin. */
function at(eastM: number, northM: number): Pt {
  return {
    lat: ORIGIN.lat + northM / M_PER_DEG_LAT,
    lng: ORIGIN.lng + eastM / M_PER_DEG_LNG,
  };
}

function eastOf(p: Pt): number {
  return (p.lng - ORIGIN.lng) * M_PER_DEG_LNG;
}

function gapM(a: Pt, b: Pt): number {
  const dx = (b.lng - a.lng) * M_PER_DEG_LNG;
  const dy = (b.lat - a.lat) * M_PER_DEG_LAT;
  return Math.hypot(dx, dy);
}

function assertContiguous(chain: Pt[]): void {
  for (let i = 1; i < chain.length; i++) {
    assert(
      gapM(chain[i - 1], chain[i]) < CELL_M * 3.5,
      `gap at chain index ${i}`,
    );
  }
}

Deno.test("partial trips A..C and C..E form one ordered chain", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(50, 0), at(100, 0)]);
  addTrip(acc, [at(100, 0), at(150, 0), at(200, 0)]);

  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);
  assertEquals(acc.tripCount, 2);
  assert(eastOf(chain![0]) < CELL_M);
  assert(eastOf(chain![chain!.length - 1]) > 190);
  for (let i = 1; i < chain!.length; i++) {
    assert(eastOf(chain![i]) >= eastOf(chain![i - 1]));
  }
  assertContiguous(chain!);
});

Deno.test("opposite direction in another accumulator leaves the chain alone", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(50, 0), at(100, 0)]);
  const before = buildChain(acc, CONFIG);

  const reverseAcc = newCorridorAcc(1, 1, ORIGIN, CELL_M);
  addTrip(reverseAcc, [at(100, 0), at(50, 0), at(0, 0)]);

  const after = buildChain(acc, CONFIG);
  assertEquals(after, before);

  const reverse = buildChain(reverseAcc, CONFIG);
  assert(reverse !== null);
  assert(eastOf(reverse![0]) > 90);
  assert(eastOf(reverse![reverse!.length - 1]) < CELL_M);
});

Deno.test("sparse long trip plus short overlap stays contiguous", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  // Fixes 300 m apart: interpolation must bridge cells between them.
  addTrip(acc, [at(0, 0), at(300, 0), at(600, 0)]);
  addTrip(acc, [at(300, 0), at(375, 0), at(450, 0)]);

  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);
  assert(eastOf(chain![0]) < CELL_M);
  assert(eastOf(chain![chain!.length - 1]) > 590);
  assertContiguous(chain!);
});

Deno.test("disconnected clusters keep only the longest run", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(100, 0), at(200, 0)]);
  addTrip(acc, [at(1000, 0), at(1050, 0), at(1100, 0)]);

  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);
  for (const p of chain!) assert(eastOf(p) < 500);
  assert(eastOf(chain![chain!.length - 1]) > 190);

  const shortAcc = newCorridorAcc(2, 0, ORIGIN, CELL_M);
  addTrip(shortAcc, [at(0, 0), at(20, 0)]);
  assertEquals(buildChain(shortAcc, { ...CONFIG, minCells: 5 }), null);
});

Deno.test("loop route closes on the start cell", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [
    at(0, 0),
    at(100, 0),
    at(100, 100),
    at(0, 100),
    at(0, 0),
  ]);

  const chain = buildChain(acc, { ...CONFIG, minCells: 5 });
  assert(chain !== null);
  assert(chain!.length > 10);
  assertEquals(chain![0], chain![chain!.length - 1]);
});

Deno.test("weak stray edge into the head does not hide the corridor", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  const corridor = [at(0, 0), at(100, 0), at(200, 0), at(300, 0), at(400, 0)];
  addTrip(acc, corridor);
  addTrip(acc, corridor);
  // One weight-1 glitch edge points at the corridor head.
  addTrip(acc, [at(-200, 0), at(5, 0)]);

  const chain = buildChain(acc, { ...CONFIG, minEdgeWeight: 2 });
  assert(chain !== null);
  assert(eastOf(chain![0]) < CELL_M);
  assert(eastOf(chain![chain!.length - 1]) > 390);
  assert(chain!.length > 30);
});

Deno.test("isolated edgeless cell does not hide a loop", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [
    at(0, 0),
    at(100, 0),
    at(100, 100),
    at(0, 100),
    at(0, 0),
  ]);
  const cellsBefore = acc.cells.size;
  addTrip(acc, [at(5000, 0), at(5001, 0)]);
  assert(acc.cells.size > cellsBefore);

  const chain = buildChain(acc, { ...CONFIG, minCells: 5 });
  assert(chain !== null);
  assert(chain!.length > 10);
  assertEquals(chain![0], chain![chain!.length - 1]);
});

Deno.test("oversized jump is dropped and cell count stays bounded", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(100, 0), at(200, 0)]);
  const cellsBefore = acc.cells.size;
  const edgesBefore = acc.edges.size;
  const tripsBefore = acc.tripCount;

  // Default maxGapM is 500 m: this 4 km segment must not be sampled.
  addTrip(acc, [at(200, 0), at(4200, 0)]);
  assertEquals(acc.cells.size, cellsBefore);
  assertEquals(acc.edges.size, edgesBefore);
  assertEquals(acc.tripCount, tripsBefore);

  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);
  assert(eastOf(chain![0]) < CELL_M);
  assert(eastOf(chain![chain!.length - 1]) > 190);
  assert(acc.cells.size < 100);

  const explicit = newCorridorAcc(2, 0, ORIGIN, CELL_M);
  addTrip(explicit, [at(0, 0), at(200, 0)], { ...CONFIG, maxGapM: 100 });
  assertEquals(explicit.cells.size, 0);
  assertEquals(explicit.tripCount, 0);
});

Deno.test("long low-weight spur does not replace heavy corridor", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  const corridor = [at(0, 0), at(100, 0), at(200, 0)];
  for (let trip = 0; trip < 5; trip++) addTrip(acc, corridor);
  // Longer in cells, but each edge was observed only once.
  addTrip(acc, [at(1000, 0), at(1100, 0), at(1200, 0), at(1300, 0)]);

  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);
  for (const p of chain!) assert(eastOf(p) < 500);
  assert(eastOf(chain![chain!.length - 1]) > 190);
});

Deno.test("walk ending on its start cell has no duplicated vertex", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [
    at(0, 0),
    at(100, 0),
    at(100, 100),
    at(0, 100),
    at(0, 0),
  ]);

  const chain = buildChain(acc, { ...CONFIG, minCells: 5 });
  assert(chain !== null);
  const first = chain![0];
  const last = chain![chain!.length - 1];
  const beforeLast = chain![chain!.length - 2];
  assertEquals(last, first);
  assertNotEquals(beforeLast, first);
});

Deno.test("coverage score separates corridor points from far points", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(50, 0), at(100, 0)]);

  assertEquals(coverageScore(acc, []), 0);
  assertEquals(
    coverageScore(acc, [at(0, 0), at(50, 0), at(100, 0)]),
    1,
  );
  assertEquals(coverageScore(acc, [at(10_000, 10_000)]), 0);
  assertEquals(coverageScore(acc, [at(-10_000, -10_000)]), 0);
});

Deno.test("assignOrdinals projects stops in chain order", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, [at(0, 0), at(150, 0), at(300, 0)]);
  const chain = buildChain(acc, CONFIG);
  assert(chain !== null);

  // Input order is scrambled and two stops sit slightly off the chain.
  assertEquals(
    assignOrdinals([at(250, 10), at(50, -5), at(150, 5)], chain!),
    [2, 0, 1],
  );
  // Beyond the chain ends clamps to the nearer end.
  assertEquals(assignOrdinals([at(-100, 0), at(400, 0)], chain!), [0, 1]);
  // Ties keep input order.
  assertEquals(assignOrdinals([at(100, 0), at(100, 0)], chain!), [0, 1]);
});

Deno.test("addTrip ignores short trips and duplicate points", () => {
  const acc = newCorridorAcc(1, 0, ORIGIN, CELL_M);
  addTrip(acc, []);
  addTrip(acc, [at(0, 0)]);
  assertEquals(acc.tripCount, 0);
  assertEquals(acc.cells.size, 0);

  addTrip(acc, [at(0, 0), at(0, 0), at(0, 0)]);
  assertEquals(acc.tripCount, 0);
  assertEquals(acc.edges.size, 0);

  addTrip(acc, [{ lat: NaN, lng: 0 }, { lat: 0, lng: NaN }]);
  assertEquals(acc.tripCount, 0);
});

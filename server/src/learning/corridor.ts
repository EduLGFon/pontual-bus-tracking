// Absolute-space corridor geometry for the learning subsystem.
// Trip fixes cover partial routes, so progress-relative bins cannot place them
// in a shared frame. This module accumulates samples in a metric grid anchored
// at a per-line origin and walks the observed directed cell graph to produce an
// ordered polyline. Pure functions only: no I/O, clock, randomness, or module
// state. Coordinates stay in memory as aggregate cell centroids.

export interface Pt {
  lat: number;
  lng: number;
}

export interface CorridorConfig {
  cellM: number;
  minEdgeWeight: number;
  minCells: number;
}

export interface CorridorCell {
  lat: number;
  lng: number;
  n: number;
}

export interface CorridorAcc {
  lineId: number;
  direction: number;
  originLat: number;
  originLng: number;
  cellM: number;
  cells: Map<string, CorridorCell>;
  edges: Map<string, number>;
  tripCount: number;
  lastPublishedTripCount: number;
}

const M_PER_DEG_LAT = 111320;

export function newCorridorAcc(
  lineId: number,
  direction: number,
  origin: Pt,
  cellM: number,
): CorridorAcc {
  if (!Number.isFinite(cellM) || cellM <= 0) {
    throw new RangeError("cellM must be a positive finite number");
  }
  if (!Number.isFinite(origin.lat) || !Number.isFinite(origin.lng)) {
    throw new RangeError("origin must have finite coordinates");
  }
  return {
    lineId,
    direction,
    originLat: origin.lat,
    originLng: origin.lng,
    cellM,
    cells: new Map(),
    edges: new Map(),
    tripCount: 0,
    lastPublishedTripCount: 0,
  };
}

/** Grid cell containing a point, or null for non-finite input. */
function cellKey(acc: CorridorAcc, p: Pt): string | null {
  if (!Number.isFinite(p.lat) || !Number.isFinite(p.lng)) return null;
  const cosLat = Math.cos((acc.originLat * Math.PI) / 180);
  const x = Math.floor(
    ((p.lng - acc.originLng) * M_PER_DEG_LAT * cosLat) / acc.cellM,
  );
  const y = Math.floor(((p.lat - acc.originLat) * M_PER_DEG_LAT) / acc.cellM);
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  return `${x}:${y}`;
}

function parseCellKey(key: string): { x: number; y: number } | null {
  const parts = key.split(":");
  if (parts.length !== 2) return null;
  const x = Number(parts[0]);
  const y = Number(parts[1]);
  if (!Number.isInteger(x) || !Number.isInteger(y)) return null;
  return { x, y };
}

function parseEdgeKey(key: string): { from: string; to: string } | null {
  const sep = key.indexOf(">");
  if (sep <= 0 || sep === key.length - 1) return null;
  return { from: key.slice(0, sep), to: key.slice(sep + 1) };
}

function updateCell(acc: CorridorAcc, key: string, p: Pt): void {
  const cell = acc.cells.get(key);
  if (!cell) {
    acc.cells.set(key, { lat: p.lat, lng: p.lng, n: 1 });
    return;
  }
  cell.n += 1;
  cell.lat += (p.lat - cell.lat) / cell.n;
  cell.lng += (p.lng - cell.lng) / cell.n;
}

/**
 * Sample one segment at roughly cellM/2 spacing and record its cells and
 * transitions. Returns the number of cell transitions observed.
 */
function addSegment(acc: CorridorAcc, a: Pt, b: Pt): number {
  if (!Number.isFinite(a.lat) || !Number.isFinite(a.lng)) return 0;
  if (!Number.isFinite(b.lat) || !Number.isFinite(b.lng)) return 0;
  const cosLat = Math.cos((acc.originLat * Math.PI) / 180);
  const dxM = (b.lng - a.lng) * M_PER_DEG_LAT * cosLat;
  const dyM = (b.lat - a.lat) * M_PER_DEG_LAT;
  const distanceM = Math.hypot(dxM, dyM);
  if (!Number.isFinite(distanceM)) return 0;
  const steps = Math.max(1, Math.ceil(distanceM / (acc.cellM / 2)));
  let prevKey: string | null = null;
  let transitions = 0;
  for (let step = 0; step <= steps; step++) {
    const t = step / steps;
    const p = {
      lat: a.lat + (b.lat - a.lat) * t,
      lng: a.lng + (b.lng - a.lng) * t,
    };
    const key = cellKey(acc, p);
    if (key === null) {
      prevKey = null;
      continue;
    }
    updateCell(acc, key, p);
    if (prevKey !== null && key !== prevKey) {
      const edgeKey = `${prevKey}>${key}`;
      acc.edges.set(edgeKey, (acc.edges.get(edgeKey) ?? 0) + 1);
      transitions += 1;
    }
    prevKey = key;
  }
  return transitions;
}

export function addTrip(acc: CorridorAcc, pts: Pt[]): void {
  if (pts.length < 2) return;
  let transitions = 0;
  for (let i = 1; i < pts.length; i++) {
    transitions += addSegment(acc, pts[i - 1], pts[i]);
  }
  if (transitions > 0) acc.tripCount += 1;
}

interface DirectedEdge {
  to: string;
  weight: number;
}

function buildAdjacency(acc: CorridorAcc): {
  adjacency: Map<string, DirectedEdge[]>;
  inDegree: Map<string, number>;
} {
  const adjacency = new Map<string, DirectedEdge[]>();
  const inDegree = new Map<string, number>();
  for (const [key, weight] of acc.edges) {
    if (!Number.isFinite(weight) || weight <= 0) continue;
    const edge = parseEdgeKey(key);
    if (!edge) continue;
    const list = adjacency.get(edge.from);
    if (list) list.push({ to: edge.to, weight });
    else adjacency.set(edge.from, [{ to: edge.to, weight }]);
    inDegree.set(edge.to, (inDegree.get(edge.to) ?? 0) + 1);
  }
  for (const list of adjacency.values()) {
    list.sort((a, b) => (a.to < b.to ? -1 : a.to > b.to ? 1 : 0));
  }
  return { adjacency, inDegree };
}

/** Bearing in radians from one cell centroid to another. */
function bearing(acc: CorridorAcc, from: string, to: string): number {
  const a = acc.cells.get(from);
  const b = acc.cells.get(to);
  if (!a || !b) return 0;
  const cosLat = Math.cos((((a.lat + b.lat) / 2) * Math.PI) / 180);
  const dx = (b.lng - a.lng) * cosLat;
  const dy = b.lat - a.lat;
  return Math.atan2(dx, dy);
}

function angleChange(a: number, b: number): number {
  let diff = b - a;
  if (diff > Math.PI) diff -= 2 * Math.PI;
  else if (diff < -Math.PI) diff += 2 * Math.PI;
  return Math.abs(diff);
}

/**
 * Highest weight first. Ties prefer the straightest continuation, then the
 * lexicographic target key so the result is deterministic.
 */
function compareEdges(
  acc: CorridorAcc,
  from: string,
  incoming: number | null,
  a: DirectedEdge,
  b: DirectedEdge,
): number {
  if (a.weight !== b.weight) return b.weight - a.weight;
  const turnA = incoming === null
    ? 0
    : angleChange(incoming, bearing(acc, from, a.to));
  const turnB = incoming === null
    ? 0
    : angleChange(incoming, bearing(acc, from, b.to));
  if (turnA !== turnB) return turnA - turnB;
  return a.to < b.to ? -1 : a.to > b.to ? 1 : 0;
}

function walkFrom(
  acc: CorridorAcc,
  adjacency: Map<string, DirectedEdge[]>,
  start: string,
  minEdgeWeight: number,
): string[] {
  const path = [start];
  const used = new Set<string>();
  let current = start;
  let incoming: number | null = null;
  while (true) {
    const edges = adjacency.get(current) ?? [];
    const candidates = edges.filter((e) =>
      e.weight >= minEdgeWeight && !used.has(`${current}>${e.to}`)
    );
    if (candidates.length === 0) break;
    candidates.sort((a, b) => compareEdges(acc, current, incoming, a, b));
    const next = candidates[0];
    used.add(`${current}>${next.to}`);
    incoming = bearing(acc, current, next.to);
    current = next.to;
    path.push(current);
  }
  return path;
}

/** True when two cell keys are the same or 8-neighbours on the grid. */
function cellsAdjacent(a: string, b: string): boolean {
  if (a === b) return true;
  const ca = parseCellKey(a);
  const cb = parseCellKey(b);
  if (!ca || !cb) return false;
  return Math.abs(ca.x - cb.x) <= 1 && Math.abs(ca.y - cb.y) <= 1;
}

function cellPoint(acc: CorridorAcc, key: string): Pt | null {
  const cell = acc.cells.get(key);
  return cell ? { lat: cell.lat, lng: cell.lng } : null;
}

export function buildChain(
  acc: CorridorAcc,
  cfg: CorridorConfig,
): Pt[] | null {
  const { adjacency, inDegree } = buildAdjacency(acc);
  const nodes = [
    ...new Set([
      ...acc.cells.keys(),
      ...adjacency.keys(),
      ...inDegree.keys(),
    ]),
  ].sort();
  if (nodes.length === 0) return null;

  const hasSource = nodes.some((key) => (inDegree.get(key) ?? 0) === 0);
  const starts = hasSource
    ? nodes.filter((key) => (inDegree.get(key) ?? 0) === 0)
    : nodes;

  let best: string[] = [];
  for (const start of starts) {
    const walk = walkFrom(acc, adjacency, start, cfg.minEdgeWeight);
    if (walk.length > best.length) best = walk;
  }
  if (
    !hasSource && best.length > 1 &&
    cellsAdjacent(best[best.length - 1], best[0])
  ) {
    best = [...best, best[0]];
  }

  const points: Pt[] = [];
  for (const key of best) {
    const p = cellPoint(acc, key);
    if (p) points.push(p);
  }
  return points.length >= cfg.minCells ? points : null;
}

export function coverageScore(acc: CorridorAcc, pts: Pt[]): number {
  if (pts.length === 0) return 0;
  let covered = 0;
  for (const p of pts) {
    const key = cellKey(acc, p);
    if (key !== null && acc.cells.has(key)) covered += 1;
  }
  return covered / pts.length;
}

function segmentLengthM(a: Pt, b: Pt): number {
  const cosLat = Math.cos((((a.lat + b.lat) / 2) * Math.PI) / 180);
  const dx = (b.lng - a.lng) * M_PER_DEG_LAT * cosLat;
  const dy = (b.lat - a.lat) * M_PER_DEG_LAT;
  return Math.hypot(dx, dy);
}

function cumulativeDistances(chain: Pt[]): number[] {
  const cumulative = new Array<number>(chain.length).fill(0);
  for (let i = 1; i < chain.length; i++) {
    cumulative[i] = cumulative[i - 1] + segmentLengthM(chain[i - 1], chain[i]);
  }
  return cumulative;
}

/** Distance along the chain of the nearest point on any segment. */
function projectAlongM(p: Pt, chain: Pt[], cumulative: number[]): number {
  let bestDist2 = Infinity;
  let bestAlong = 0;
  for (let i = 0; i < chain.length - 1; i++) {
    const a = chain[i];
    const b = chain[i + 1];
    const cosLat = Math.cos((((a.lat + b.lat) / 2) * Math.PI) / 180);
    const px = (p.lng - a.lng) * M_PER_DEG_LAT * cosLat;
    const py = (p.lat - a.lat) * M_PER_DEG_LAT;
    const bx = (b.lng - a.lng) * M_PER_DEG_LAT * cosLat;
    const by = (b.lat - a.lat) * M_PER_DEG_LAT;
    const len2 = bx * bx + by * by;
    let t = len2 === 0 ? 0 : (px * bx + py * by) / len2;
    t = Math.max(0, Math.min(1, t));
    const dx = px - t * bx;
    const dy = py - t * by;
    const dist2 = dx * dx + dy * dy;
    if (dist2 < bestDist2) {
      bestDist2 = dist2;
      bestAlong = cumulative[i] + t * Math.sqrt(len2);
    }
  }
  return bestAlong;
}

export function assignOrdinals(stops: Pt[], chain: Pt[]): number[] {
  if (stops.length === 0) return [];
  if (chain.length < 2) return stops.map((_, i) => i);
  const cumulative = cumulativeDistances(chain);
  const ranked = stops.map((stop, index) => ({
    index,
    along: projectAlongM(stop, chain, cumulative),
  }));
  ranked.sort((a, b) => a.along - b.along || a.index - b.index);
  const ordinals = new Array<number>(stops.length);
  for (let rank = 0; rank < ranked.length; rank++) {
    ordinals[ranked[rank].index] = rank;
  }
  return ordinals;
}

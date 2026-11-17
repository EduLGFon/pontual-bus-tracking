// Pure stop grouping for the global learned-stop read endpoints.
// Merges stops that represent the same physical place across lines and
// directions. No I/O, no clock. See ARCHITECTURE.md 6.5.
import { distM } from "./geo.ts";

/** Radius used by the global stop endpoints to merge physical stops. */
export const stopMergeRadiusM = 50;

export interface StopMember {
  id: string;
  lineId: number;
  direction: number;
  lat: number;
  lng: number;
  radiusM: number;
  passes: number;
}

export interface StopGroup {
  id: string;
  lat: number;
  lng: number;
  radiusM: number;
  passes: number;
  members: StopMember[];
}

function finite(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n);
}

function normPasses(v: unknown): number {
  return finite(v) ? (v as number) : 0;
}

function normRadius(v: unknown): number {
  return finite(v) && (v as number) >= 0 ? (v as number) : 0;
}

/**
 * Merge active stop members that are within `mergeRadiusM` metres of a
 * stronger anchor. Members are sorted by passes desc then id asc; the first
 * unmerged member becomes the geometric anchor of a new group and pulls in
 * every later unassigned member within range. A spatial hash grid of cell
 * size `mergeRadiusM` keeps this near-linear by checking only the anchor's
 * 3x3 neighbouring cells. Group coordinates are a passes-weighted centroid;
 * radius and passes are the group maxima. The group id is the
 * lexicographically smallest member stop id: stable and deterministic while
 * membership is unchanged, but not promised across membership changes.
 */
export function groupStops(
  members: readonly StopMember[],
  mergeRadiusM = stopMergeRadiusM,
): StopGroup[] {
  const radius = Number.isFinite(mergeRadiusM) && mergeRadiusM >= 0
    ? mergeRadiusM
    : 0;

  const valid: StopMember[] = [];
  for (const m of members ?? []) {
    if (!m || typeof m.id !== "string") continue;
    if (!finite(m.lat) || !finite(m.lng)) continue;
    if (!Number.isFinite(m.lineId)) continue;
    if (!Number.isFinite(m.direction)) continue;
    valid.push({
      id: m.id,
      lineId: m.lineId,
      direction: m.direction,
      lat: m.lat,
      lng: m.lng,
      radiusM: normRadius(m.radiusM),
      passes: normPasses(m.passes),
    });
  }
  if (valid.length === 0) return [];

  // Strongest first; id asc breaks ties deterministically.
  const sorted = [...valid].sort((a, b) => {
    if (b.passes !== a.passes) return b.passes - a.passes;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  // Approximate metres. Learned stops are city-scale, so one longitude scale
  // from the mean latitude is accurate enough for a radius-sized cell grid.
  let meanLat = 0;
  for (const m of valid) meanLat += m.lat;
  meanLat /= valid.length;
  const latMetersPerDeg = 111320;
  const lngMetersPerDeg = Math.max(
    1,
    111320 * Math.cos((meanLat * Math.PI) / 180),
  );
  // A zero radius still groups identical coordinates; a tiny cell keeps the
  // grid finite without changing the inclusive `<= radius` test.
  const cellM = radius > 0 ? radius : 1e-6;
  const cellOf = (lat: number, lng: number) => ({
    x: Math.floor((lat * latMetersPerDeg) / cellM),
    y: Math.floor((lng * lngMetersPerDeg) / cellM),
  });

  const buckets = new Map<string, number[]>();
  for (let i = 0; i < sorted.length; i++) {
    const c = cellOf(sorted[i].lat, sorted[i].lng);
    const key = `${c.x}:${c.y}`;
    const bucket = buckets.get(key);
    if (bucket) bucket.push(i);
    else buckets.set(key, [i]);
  }

  const groups: StopGroup[] = [];
  const assigned = new Set<number>();
  for (let i = 0; i < sorted.length; i++) {
    if (assigned.has(i)) continue;
    const anchor = sorted[i];
    const memberIdxs: number[] = [i];
    assigned.add(i);
    const c = cellOf(anchor.lat, anchor.lng);
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        const bucket = buckets.get(`${c.x + dx}:${c.y + dy}`);
        if (!bucket) continue;
        for (const j of bucket) {
          // Earlier members are already assigned; only later unassigned
          // members can join this anchor.
          if (j <= i || assigned.has(j)) continue;
          const cand = sorted[j];
          if (distM(anchor.lat, anchor.lng, cand.lat, cand.lng) <= radius) {
            memberIdxs.push(j);
            assigned.add(j);
          }
        }
      }
    }

    const groupMembers = memberIdxs
      .map((k) => sorted[k])
      .sort((a, b) => {
        if (a.lineId !== b.lineId) return a.lineId - b.lineId;
        if (a.direction !== b.direction) return a.direction - b.direction;
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
      });

    let weightSum = 0;
    let latSum = 0;
    let lngSum = 0;
    let radiusMax = 0;
    let passesMax = 0;
    let minId = groupMembers[0].id;
    for (const m of groupMembers) {
      const w = m.passes > 0 ? m.passes : 1;
      weightSum += w;
      latSum += m.lat * w;
      lngSum += m.lng * w;
      if (m.radiusM > radiusMax) radiusMax = m.radiusM;
      if (m.passes > passesMax) passesMax = m.passes;
      if (m.id < minId) minId = m.id;
    }
    const lat = weightSum > 0 ? latSum / weightSum : anchor.lat;
    const lng = weightSum > 0 ? lngSum / weightSum : anchor.lng;

    groups.push({
      id: minId,
      lat,
      lng,
      radiusM: radiusMax,
      passes: passesMax,
      members: groupMembers,
    });
  }

  groups.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return groups;
}

export function findStopGroup(
  groups: readonly StopGroup[],
  id: string,
): StopGroup | undefined {
  return groups.find((g) => g.id === id);
}

// Snapshot builder. Public payload exposes vehicles only: no device or
// trip ids, no battery, member count capped at 3. Coordinates at 5 decimals.
// Row field 7 (paceKmh) is optional and additive: old readers use fields
// 0-6 unchanged. See PLAN.md 6.6 snapshot format and DECISIONS.md#D30.
import type { Trip, Vehicle } from "./types.ts";

export type SnapshotRow = [
  number,
  number,
  number,
  number | null,
  number,
  number,
  number,
  number?,
];

export interface Snapshot {
  t: number;
  v: SnapshotRow[];
}

function round5(n: number): number {
  return Math.round(n * 100000) / 100000;
}

/** Build the public snapshot for one line. */
export function buildSnapshot(
  vehicles: Vehicle[],
  membersByVehicle: Map<number, Trip[]>,
  lineId: number,
  nowMs: number,
  publishTtlS: number,
): Snapshot {
  const t = Math.floor(nowMs / 1000);
  const rows: SnapshotRow[] = [];
  for (const v of vehicles) {
    if (v.lineId !== lineId) continue;
    const ageS = Math.floor((nowMs - v.fixAtMs) / 1000);
    if (ageS > publishTtlS) continue;
    const n = Math.min(3, (membersByVehicle.get(v.id) ?? []).length);
    const kmh = Math.round(v.speedMps * 3.6 * 10) / 10;
    const paceKmh = Math.round(v.paceMps * 3.6 * 10) / 10;
    rows.push([
      v.id,
      round5(v.lat),
      round5(v.lng),
      v.heading,
      kmh,
      n,
      ageS,
      paceKmh,
    ]);
  }
  rows.sort((a, b) => a[0] - b[0]);
  return { t, v: rows };
}

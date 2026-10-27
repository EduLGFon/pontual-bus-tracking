// Public snapshot payloads. Vehicles plus optional passenger reports, never
// trips or device data. Coordinates at 5 decimals, member count capped at 3.
// See PLAN.md 6.6 and DECISIONS.md#D82/D83.
import { buildSnapshot } from "../domain/snapshot.ts";
import type { SnapshotRow } from "../domain/snapshot.ts";
import { reportRows } from "../domain/reports.ts";
import { membersByVehicle, vehiclesOfLine } from "../domain/store.ts";
import type { Store } from "../domain/store.ts";

/** Structured vehicle rows for one line, without stringifying. */
export function snapshotRows(
  store: Store,
  lineId: number,
  nowMs: number,
  publishTtlS: number,
  memberAliveS: number,
): SnapshotRow[] {
  const vehicles = vehiclesOfLine(store, lineId);
  const members = membersByVehicle(store, nowMs, memberAliveS);
  return buildSnapshot(vehicles, members, lineId, nowMs, publishTtlS).v;
}

/** Snapshot body for one line plus its ETag. */
export function lineSnapshot(
  store: Store,
  lineId: number,
  nowMs: number,
  publishTtlS: number,
  memberAliveS: number,
  includeReports: boolean,
): { body: string; etag: string } {
  const snap = {
    t: Math.floor(nowMs / 1000),
    v: snapshotRows(store, lineId, nowMs, publishTtlS, memberAliveS),
    // Always present so a disabled feature clears a client that still
    // holds an older report list. Old clients ignore the key.
    r: includeReports ? reportRows(store, lineId, nowMs) : [],
  };
  const body = JSON.stringify(snap);
  return { body, etag: etagOf(body) };
}

/** Live-lines payload: only lines with a published vehicle. */
export function livePayload(
  store: Store,
  nowMs: number,
  publishTtlS: number,
): { body: string } {
  const rows: [number, number][] = [];
  for (const [lineId, ids] of store.byLine) {
    // Count published vehicles directly: building a full snapshot per
    // line only to read its length wastes CPU on every /v1/live call.
    let count = 0;
    for (const id of ids) {
      const v = store.vehicles.get(id);
      if (v && Math.floor((nowMs - v.fixAtMs) / 1000) <= publishTtlS) {
        count++;
      }
    }
    if (count > 0) rows.push([lineId, count]);
  }
  rows.sort((a, b) => a[0] - b[0]);
  return { body: JSON.stringify(rows) };
}

/** Weak ETag from a tiny content hash. */
export function etagOf(body: string): string {
  let h = 5381;
  for (let i = 0; i < body.length; i++) {
    h = ((h << 5) + h + body.charCodeAt(i)) | 0;
  }
  return `W/"${(h >>> 0).toString(16)}-${body.length}"`;
}

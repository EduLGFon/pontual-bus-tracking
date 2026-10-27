// In-memory engine state shared by the pure domain functions. The shape
// lives in domain/ so the engine imports nothing outside its own layer;
// state/store.ts owns construction. Location exists only in this memory and
// is dropped when a trip ends. See PLAN.md D02, 6.6, 6.7 and 8.3.
import type { ReportState, Trip, Vehicle } from "./types.ts";

export interface Store {
  trips: Map<string, Trip>;
  vehicles: Map<number, Vehicle>;
  byLine: Map<number, Set<number>>;
  nextVehicleId: number;
  /** D30: anonymous vehicle-sighting millis per line (no positions/ids). */
  passages: Map<number, number[]>;
  /**
   * Active passenger reports per line, keyed by `kind:areaId`. In memory
   * only, pruned on the tick. PRIVACY: never serialised or persisted.
   */
  reports: Map<number, Map<string, ReportState>>;
}

export function addVehicle(store: Store, v: Vehicle): void {
  store.vehicles.set(v.id, v);
  let set = store.byLine.get(v.lineId);
  if (!set) {
    set = new Set();
    store.byLine.set(v.lineId, set);
  }
  set.add(v.id);
}

export function removeVehicle(store: Store, id: number): void {
  const v = store.vehicles.get(id);
  if (!v) return;
  store.vehicles.delete(id);
  const set = store.byLine.get(v.lineId);
  if (set) {
    set.delete(id);
    if (set.size === 0) store.byLine.delete(v.lineId);
  }
}

export function vehiclesOfLine(store: Store, lineId: number): Vehicle[] {
  const set = store.byLine.get(lineId);
  if (!set) return [];
  const out: Vehicle[] = [];
  for (const id of set) {
    const v = store.vehicles.get(id);
    if (v) out.push(v);
  }
  return out;
}

export function membersOf(
  store: Store,
  vehicleId: number,
  nowMs: number,
  aliveS: number,
): Trip[] {
  const out: Trip[] = [];
  for (const t of store.trips.values()) {
    if (t.vehicleId !== vehicleId) continue;
    if (t.lastSeenAtMs === null) continue;
    if (nowMs - t.lastSeenAtMs > aliveS * 1000) continue;
    out.push(t);
  }
  return out;
}

/**
 * Group alive trips by vehicle in one pass. Snapshot and tick paths call
 * this once per pass instead of scanning every trip once per vehicle.
 * Trips with no accepted fix yet (null lastSeenAtMs) are omitted, exactly
 * like [membersOf].
 */
export function membersByVehicle(
  store: Store,
  nowMs: number,
  aliveS: number,
): Map<number, Trip[]> {
  const out = new Map<number, Trip[]>();
  for (const t of store.trips.values()) {
    if (t.lastSeenAtMs === null) continue;
    if (nowMs - t.lastSeenAtMs > aliveS * 1000) continue;
    const id = t.vehicleId;
    if (id === null) continue;
    const list = out.get(id);
    if (list) list.push(t);
    else out.set(id, [t]);
  }
  return out;
}

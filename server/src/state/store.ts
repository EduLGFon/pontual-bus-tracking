// In-memory store. Trips keyed by device id, vehicles by id with a line
// index. Location lives only here and is dropped when a trip ends.
// See PLAN.md D02, 6.6, 6.7. A StateStore seam allows Redis later.
import type { ReportState, Trip, Vehicle } from "../domain/types.ts";

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

export function createStore(): Store {
  return {
    trips: new Map(),
    vehicles: new Map(),
    byLine: new Map(),
    nextVehicleId: 1,
    passages: new Map(),
    reports: new Map(),
  };
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

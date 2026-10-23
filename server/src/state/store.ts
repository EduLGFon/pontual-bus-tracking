// In-memory store factory. The shape and the pure map helpers live in
// domain/store.ts so the engine keeps importing only its own layer; this
// module owns construction. See PLAN.md 8.3, 6.6, 6.7.
import type { Store } from "../domain/store.ts";

export type { Store } from "../domain/store.ts";

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

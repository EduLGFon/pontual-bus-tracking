// Zustand stores. Mirrors app/lib/app/providers.dart.
import { create } from "zustand";
import type { StaticLine } from "../data/static/staticData";
import type { ActiveTrip, SharePhase } from "../domain/trip/tripState";
import type { RemoteConfig } from "../data/api/dto";

interface TripStore {
  phase: SharePhase;
  trip: ActiveTrip | null;
  setPhase: (p: SharePhase) => void;
  setTrip: (t: ActiveTrip | null) => void;
  reset: () => void;
}
export const useTripStore = create<TripStore>((set) => ({
  phase: "idle",
  trip: null,
  setPhase: (phase) => set({ phase }),
  setTrip: (trip) => set({ trip }),
  reset: () => set({ phase: "idle", trip: null }),
}));

interface StaticStore {
  lines: StaticLine[];
  setLines: (l: StaticLine[]) => void;
}
export const useStaticStore = create<StaticStore>((set) => ({
  lines: [],
  setLines: (lines) => set({ lines }),
}));

interface RemoteConfigStore {
  config: RemoteConfig | null;
  setConfig: (c: RemoteConfig) => void;
}
export const useRemoteConfigStore = create<RemoteConfigStore>((set) => ({
  config: null,
  setConfig: (config) => set({ config }),
}));

interface VehicleStore {
  byLine: Record<number, any>;
  setSnapshot: (lineId: number, snap: any) => void;
}
export const useVehicleStore = create<VehicleStore>((set) => ({
  byLine: {},
  setSnapshot: (lineId, snap) =>
    set((s) => ({ byLine: { ...s.byLine, [lineId]: snap } })),
}));

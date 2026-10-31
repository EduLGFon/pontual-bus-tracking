// Vehicles adapter. Port of app/lib/ui/adapters/vehicles_adapter.dart.
import type { Certainty } from "../models/certainty";
import type { VehicleVM } from "../models/vehicle_vm";

export const predictedWhileS = 30;
export const predictedMinKmh = 5;

export function vehicleVmOf(vehicle: any, lineKey: string, ordinal?: number): VehicleVM {
  const ageS = vehicle?.ageS ?? 0;
  let certainty: Certainty = ageS <= 45 ? "live" : "stale";
  return {
    key: vehicle?.id ?? 0,
    lineKey,
    lat: vehicle?.lat ?? 0,
    lng: vehicle?.lng ?? 0,
    headingDeg: vehicle?.heading ?? null,
    speedKmh: vehicle?.kmh ?? null,
    ageSeconds: ageS,
    certainty,
    ordinal: ordinal ?? null,
    paceKmh: vehicle?.paceKmh ?? null,
    members: vehicle?.members ?? 1,
  };
}
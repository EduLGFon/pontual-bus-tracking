// Vehicle view model. Port of app/lib/ui/models/vehicle_vm.dart.
import type { Certainty } from "./certainty";

export interface VehicleVM {
  key: number;
  lineKey: string;
  lat: number;
  lng: number;
  headingDeg?: number | null;
  speedKmh?: number | null;
  ageSeconds: number;
  certainty: Certainty;
  ordinal?: number | null;
  paceFactor?: number | null;
  paceKmh?: number | null;
  members?: number;
}

export function vehicleShowsHeading(v: VehicleVM): boolean {
  return (
    v.certainty === "live" &&
    v.headingDeg != null &&
    (v.speedKmh ?? 0) >= 1.5
  );
}
// Trip view model. Port of app/lib/ui/models/trip_vm.dart.
export type TripPhase = "idle" | "starting" | "active" | "reconnecting" | "paused";

export interface TripVM {
  phase: TripPhase;
  lineKey?: string | null;
  lineLabel?: string;
  elapsedS?: number;
  gpsOff?: boolean;
  webHidden?: boolean;
  role?: string;
}

export function tripInProgress(t: TripVM): boolean {
  return t.phase === "starting" || t.phase === "active" || t.phase === "reconnecting" || t.phase === "paused";
}

export function tripNeedsAttention(t: TripVM): boolean {
  return t.phase === "reconnecting" || t.phase === "paused";
}
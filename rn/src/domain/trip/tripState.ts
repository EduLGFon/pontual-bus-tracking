// Trip state. Mirrors app/lib/domain/trip/trip_state.dart.
export type TripRole = "L" | "F" | "W";
export interface TripState {
  lineId: number;
  role: TripRole;
  intervalS: number;
  seq: number;
  end?: string;
}
export type SharePhase = "idle" | "starting" | "sharing" | "ending" | "ended";

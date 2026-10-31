// Trip state. Mirrors app/lib/domain/trip/trip_state.dart (sealed machine)
// plus the runtime trip record used by the RN stores.
export type TripRole = "waiting" | "leader" | "follower" | "offlineSaver";

export type TripState =
  | { kind: "idle" }
  | { kind: "consent" }
  | { kind: "permissions" }
  | { kind: "starting" }
  | { kind: "active"; role: TripRole }
  | { kind: "ending" };

export type TripEvent =
  | "tapStart" | "consentAccepted" | "consentDeclined" | "permissionsGranted"
  | "permissionsDenied" | "startConfirmed" | "startFailed" | "roleLeader"
  | "roleFollower" | "wentOffline" | "wentOnline" | "tapEnd" | "endConfirmed";

export function tripReduce(state: TripState, event: TripEvent): TripState {
  switch (state.kind) {
    case "idle":
      return event === "tapStart" ? { kind: "consent" } : state;
    case "consent":
      if (event === "consentAccepted") return { kind: "permissions" };
      if (event === "consentDeclined") return { kind: "idle" };
      return state;
    case "permissions":
      if (event === "permissionsGranted") return { kind: "starting" };
      if (event === "permissionsDenied") return { kind: "idle" };
      return state;
    case "starting":
      if (event === "startConfirmed") return { kind: "active", role: "waiting" };
      if (event === "startFailed") return { kind: "idle" };
      return state;
    case "active":
      if (event === "roleLeader") return { kind: "active", role: "leader" };
      if (event === "roleFollower") return { kind: "active", role: "follower" };
      if (event === "wentOffline") return { kind: "active", role: "offlineSaver" };
      if (event === "wentOnline") return { kind: "active", role: "waiting" };
      if (event === "tapEnd") return { kind: "ending" };
      return state;
    case "ending":
      if (event === "endConfirmed") return { kind: "idle" };
      return state;
  }
}

export function tripInProgress(state: TripState): boolean {
  return state.kind === "starting" || state.kind === "active" || state.kind === "ending";
}

export function activeRole(state: TripState): TripRole | null {
  return state.kind === "active" ? state.role : null;
}

// Runtime trip record used by stores/UI (server roles L/F/W).
export type ServerTripRole = "L" | "F" | "W";
export interface ActiveTrip {
  lineId: number;
  role: ServerTripRole;
  intervalS: number;
  seq: number;
  end?: string;
}

export type SharePhase = "idle" | "starting" | "sharing" | "ending" | "ended";

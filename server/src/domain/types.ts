// Pure domain types. No I/O, no clock, no imports outside domain/.
// See PLAN.md 6.6. Time is always a parameter (nowMs).

export type Role = "L" | "F" | "W";
export type EndReason = "idle" | "timeout" | "max_duration" | "abuse" | "user";

/**
 * Public passenger report kinds. Closed API contract; unknown values from
 * a newer client are rejected at the boundary.
 */
export type ReportKind = "waiting" | "full" | "broken" | "blocked";

/**
 * One active passenger report. Lives in API memory only, for its TTL.
 * PRIVACY: `reporters` holds device ids only to count distinct reporters,
 * dedupe repeats, and let a device retract its own contribution. It is
 * never serialised, logged, or written to the database.
 */
export interface ReportState {
  kind: ReportKind;
  lineId: number;
  stopId: string | null;
  createdAtMs: number;
  updatedAtMs: number;
  expiresAtMs: number;
  reporters: Set<string>;
}

export interface Fix {
  lat: number;
  lng: number;
  speedMps: number;
  heading: number | null;
  accuracyM: number;
  batteryPct: number;
  charging: boolean;
  seq: number;
  role: Role;
}

export interface Trip {
  deviceId: string;
  lineId: number;
  vehicleId: number | null;
  startedAtMs: number;
  lastSeenAtMs: number | null;
  seq: number;
  lat: number;
  lng: number;
  speedMps: number;
  heading: number | null;
  accuracyM: number;
  batteryPct: number;
  charging: boolean;
  role: Role;
  movingTicks: number;
  stillTicks: number;
  coherenceFail: number;
  strikes: number;
  ledS: number;
  offRoute: boolean;
}

export interface Vehicle {
  id: number;
  lineId: number;
  lat: number;
  lng: number;
  heading: number | null;
  speedMps: number;
  // PRIVACY: smoothed live speed of this vehicle only (EWMA over accepted
  // fixes). Reset at vehicle creation, dropped with the vehicle. No driver
  // or device identity, no cross-trip linkage. See DECISIONS.md#D30.
  paceMps: number;
  fixAtMs: number;
  leaderDeviceId: string | null;
  nextLeaderDeviceId: string | null;
  lastElectAtMs: number;
  updatedAtMs: number;
}

/** Tunables used by the engine. Defaults mirror PLAN.md 6.3. */
export interface EngineConfig {
  bbox: { latMin: number; latMax: number; lngMin: number; lngMax: number };
  accuracyMaxM: number;
  speedMaxMps: number;
  teleportSpeedMps: number;
  teleportMinM: number;
  strikesToEnd: number;
  routeMaxDistM: number;
  attachBaseTolM: number;
  attachSpeedFactor: number;
  attachTolMaxM: number;
  coherenceFailsToDetach: number;
  movingSpeedMps: number;
  movingTicksToPublish: number;
  leaderIntervalMovingS: number;
  leaderIntervalStillS: number;
  followerIntervalS: number;
  waitingIntervalS: number;
  leaderDeadAfterS: number;
  memberAliveS: number;
  publishTtlS: number;
  reelectEveryS: number;
  leaderMinBattery: number;
  tripTimeoutS: number;
  tripMaxS: number;
  minPingIntervalS: number;
  tickPeriodS: number;
  maxActiveTrips: number;
  /** EWMA weight for vehicle pace smoothing (0-1). Higher adapts faster. */
  paceAlpha: number;
}

export function defaultEngineConfig(): EngineConfig {
  return {
    bbox: { latMin: -19.05, latMax: -18.4, lngMin: -40.25, lngMax: -39.55 },
    accuracyMaxM: 60,
    speedMaxMps: 25,
    teleportSpeedMps: 30,
    teleportMinM: 200,
    strikesToEnd: 5,
    routeMaxDistM: 300,
    attachBaseTolM: 80,
    attachSpeedFactor: 0.5,
    attachTolMaxM: 400,
    coherenceFailsToDetach: 2,
    movingSpeedMps: 3,
    movingTicksToPublish: 1,
    leaderIntervalMovingS: 5,
    leaderIntervalStillS: 15,
    followerIntervalS: 45,
    waitingIntervalS: 5,
    leaderDeadAfterS: 45,
    memberAliveS: 300,
    publishTtlS: 120,
    reelectEveryS: 300,
    leaderMinBattery: 15,
    tripTimeoutS: 600,
    tripMaxS: 14400,
    minPingIntervalS: 4,
    tickPeriodS: 5,
    maxActiveTrips: 300,
    paceAlpha: 0.3,
  };
}

export type EngineEvent =
  | { kind: "vehicleUpdated"; lineId: number }
  | { kind: "tripEnded"; lineId: number; reason: EndReason };

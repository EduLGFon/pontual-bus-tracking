// Trip lifecycle. Pure and synchronous; time and randomness are parameters.
// Handlers check kill switch, blocklist, and consent before calling here.
// Engine checks line validity, bbox, plausibility, and capacity.
// See PLAN.md 6.6 steps for startTrip, applyPing, endTrip.
import { isCoherent, nearestVehicle } from "./attach.ts";
import { distM, distToPolylineM } from "./geo.ts";
import { impliedSpeedMps, validateFix } from "./validate.ts";
import type { Store } from "../state/store.ts";
import { addVehicle, removeVehicle, vehiclesOfLine } from "../state/store.ts";
import type {
  EndReason,
  EngineConfig,
  EngineEvent,
  Fix,
  Role,
  Trip,
  Vehicle,
} from "./types.ts";

export interface StartResult {
  ok: boolean;
  role?: Role;
  intervalS?: number;
  code?: "line" | "area" | "capacity" | "bad_request";
}

export interface PingResult {
  role: Role;
  intervalS: number;
  end?: EndReason;
  ackLeader?: boolean;
}

export type PingOutcome = PingResult | { gone: true };

export function isGone(o: PingOutcome): o is { gone: true } {
  return (o as { gone: boolean }).gone === true;
}

export interface LineInfo {
  id: number;
  isActive: boolean;
}

function currentInstruction(
  store: Store,
  trip: Trip,
  cfg: EngineConfig,
): PingResult {
  if (trip.vehicleId === null) {
    return { role: "W", intervalS: cfg.waitingIntervalS };
  }
  const v = store.vehicles.get(trip.vehicleId);
  if (!v) return { role: "W", intervalS: cfg.waitingIntervalS };
  return instructionFor(store, trip, v, cfg, 0);
}

function instructionFor(
  _store: Store,
  trip: Trip,
  v: Vehicle,
  cfg: EngineConfig,
  jitterS: number,
): PingResult {
  if (v.leaderDeviceId === trip.deviceId) {
    return {
      role: "L",
      intervalS: trip.stillTicks >= 2
        ? cfg.leaderIntervalStillS
        : cfg.leaderIntervalMovingS,
    };
  }
  if (v.nextLeaderDeviceId === trip.deviceId) {
    return { role: "L", intervalS: cfg.leaderIntervalMovingS };
  }
  return { role: "F", intervalS: cfg.followerIntervalS + jitterS };
}

/** Start a trip. Ends any existing trip of the device first. */
export function startTrip(
  store: Store,
  events: EngineEvent[],
  deviceId: string,
  line: LineInfo | null,
  fix: Fix,
  nowMs: number,
  cfg: EngineConfig,
): StartResult {
  if (!line || !line.isActive) return { ok: false, code: "line" };
  if (store.trips.size >= cfg.maxActiveTrips && !store.trips.has(deviceId)) {
    return { ok: false, code: "capacity" };
  }
  const invalid = validateFix(fix, cfg);
  if (invalid) {
    return { ok: false, code: invalid === "bbox" ? "area" : "bad_request" };
  }
  if (store.trips.has(deviceId)) endTrip(store, events, deviceId);
  store.trips.set(deviceId, {
    deviceId,
    lineId: line.id,
    vehicleId: null,
    startedAtMs: nowMs,
    lastSeenAtMs: null,
    seq: 0,
    lat: fix.lat,
    lng: fix.lng,
    speedMps: fix.speedMps,
    heading: fix.heading,
    accuracyM: fix.accuracyM,
    batteryPct: fix.batteryPct,
    charging: fix.charging,
    role: "W",
    movingTicks: 0,
    stillTicks: 0,
    coherenceFail: 0,
    strikes: 0,
    ledS: 0,
    offRoute: false,
  });
  return { ok: true, role: "W", intervalS: cfg.waitingIntervalS };
}

/** Apply a ping. Follows the normative order in PLAN.md 6.6. */
export function applyPing(
  store: Store,
  events: EngineEvent[],
  deviceId: string,
  lineRoute: { lat: number; lng: number }[] | null,
  fix: Fix,
  nowMs: number,
  cfg: EngineConfig,
  jitterS: number,
): PingOutcome {
  // 1. Trip lookup.
  const trip = store.trips.get(deviceId);
  if (!trip) return { gone: true };
  // 2. Sequence: duplicates return the current instruction unchanged.
  if (fix.seq <= trip.seq) return currentInstruction(store, trip, cfg);
  // 3. Rate limit: ignore too-frequent pings without a strike and keep
  // sampling the stream at ~minPingIntervalS. Striking here killed
  // legitimate web clients whose position stream runs faster than the
  // instructed interval (geolocator-web ignores Android interval
  // settings). Spoofing defense stays via validate/teleport strikes
  // below plus the per-device ping bucket. See DECISIONS.md.
  if (
    trip.lastSeenAtMs !== null &&
    nowMs - trip.lastSeenAtMs < cfg.minPingIntervalS * 1000
  ) {
    return currentInstruction(store, trip, cfg);
  }
  // 4. Validate.
  if (validateFix(fix, cfg)) {
    return strike(store, events, trip, cfg);
  }
  // 5. Teleport.
  if (trip.lastSeenAtMs !== null) {
    const dist = distM(trip.lat, trip.lng, fix.lat, fix.lng);
    const spd = impliedSpeedMps(
      trip.lat,
      trip.lng,
      trip.lastSeenAtMs,
      fix.lat,
      fix.lng,
      nowMs,
      distM,
    );
    if (spd > cfg.teleportSpeedMps && dist > cfg.teleportMinM) {
      return strike(store, events, trip, cfg);
    }
  }
  // 6. Route check: store but do not attach or publish, no strike.
  if (
    lineRoute && lineRoute.length > 0 &&
    distToPolylineM(fix.lat, fix.lng, lineRoute) > cfg.routeMaxDistM
  ) {
    storeFix(trip, fix, nowMs, cfg);
    trip.vehicleId = null;
    trip.offRoute = true;
    return { role: "W", intervalS: cfg.waitingIntervalS };
  }
  trip.offRoute = false;
  // 7. Store the fix.
  storeFix(trip, fix, nowMs, cfg);
  // 8. Attach.
  if (trip.vehicleId === null) {
    const found = nearestVehicle(
      vehiclesOfLine(store, trip.lineId),
      trip.lineId,
      trip.lat,
      trip.lng,
      trip.speedMps,
      nowMs,
      cfg,
    );
    if (found) {
      trip.vehicleId = found.id;
      trip.coherenceFail = 0;
      if (!found.leaderDeviceId) {
        found.leaderDeviceId = trip.deviceId;
        trip.role = "L";
      }
    } else if (trip.movingTicks >= cfg.movingTicksToPublish) {
      const id = store.nextVehicleId++;
      addVehicle(store, {
        id,
        lineId: trip.lineId,
        lat: trip.lat,
        lng: trip.lng,
        heading: trip.heading,
        speedMps: trip.speedMps,
        paceMps: trip.speedMps,
        fixAtMs: nowMs,
        leaderDeviceId: trip.deviceId,
        nextLeaderDeviceId: null,
        lastElectAtMs: nowMs,
        updatedAtMs: nowMs,
      });
      trip.vehicleId = id;
      trip.role = "L";
      return { role: "L", intervalS: cfg.leaderIntervalMovingS };
    } else {
      return { role: "W", intervalS: cfg.waitingIntervalS };
    }
  } else {
    const v = store.vehicles.get(trip.vehicleId);
    if (!v) {
      trip.vehicleId = null;
      return { role: "W", intervalS: cfg.waitingIntervalS };
    }
    if (!isCoherent(trip, v, nowMs, cfg)) {
      trip.coherenceFail += 1;
      if (trip.coherenceFail >= cfg.coherenceFailsToDetach) {
        trip.vehicleId = null;
        trip.coherenceFail = 0;
        return { role: "W", intervalS: cfg.waitingIntervalS };
      }
    } else {
      trip.coherenceFail = 0;
    }
  }
  // 9. Update vehicle when newer.
  const v = trip.vehicleId !== null
    ? store.vehicles.get(trip.vehicleId)
    : undefined;
  if (v && nowMs >= v.fixAtMs) {
    v.lat = trip.lat;
    v.lng = trip.lng;
    v.heading = trip.heading;
    v.speedMps = trip.speedMps;
    // D30 pace: EWMA toward the newest accepted fix. Adapts within about
    // a minute at leader cadence, so an hourly driver change is picked up
    // without keeping any history beyond this scalar.
    v.paceMps = Math.max(
      0,
      v.paceMps + cfg.paceAlpha * (trip.speedMps - v.paceMps),
    );
    v.fixAtMs = nowMs;
    v.updatedAtMs = nowMs;
    events.push({ kind: "vehicleUpdated", lineId: trip.lineId });
  }
  // 10. Role and interval, with two-phase hand-over.
  if (trip.vehicleId === null || !v) {
    return { role: "W", intervalS: cfg.waitingIntervalS };
  }
  if (v.leaderDeviceId === trip.deviceId) {
    trip.role = "L";
    return {
      role: "L",
      intervalS: trip.stillTicks >= 2
        ? cfg.leaderIntervalStillS
        : cfg.leaderIntervalMovingS,
    };
  }
  if (v.nextLeaderDeviceId === trip.deviceId) {
    trip.role = "L";
    if (fix.role === "L") {
      v.leaderDeviceId = trip.deviceId;
      v.nextLeaderDeviceId = null;
      return {
        role: "L",
        intervalS: cfg.leaderIntervalMovingS,
        ackLeader: true,
      };
    }
    return { role: "L", intervalS: cfg.leaderIntervalMovingS };
  }
  trip.role = "F";
  return { role: "F", intervalS: cfg.followerIntervalS + jitterS };
}

function strike(
  store: Store,
  events: EngineEvent[],
  trip: Trip,
  cfg: EngineConfig,
): PingResult {
  trip.strikes += 1;
  if (trip.strikes >= cfg.strikesToEnd) {
    return endWith(store, events, trip, "abuse", cfg);
  }
  return currentInstruction(store, trip, cfg);
}

function endWith(
  store: Store,
  events: EngineEvent[],
  trip: Trip,
  reason: EndReason,
  cfg: EngineConfig,
): PingResult {
  endTrip(store, events, trip.deviceId, reason);
  return { role: "W", intervalS: cfg.waitingIntervalS, end: reason };
}

function storeFix(
  trip: Trip,
  fix: Fix,
  nowMs: number,
  cfg: EngineConfig,
): void {
  trip.seq = fix.seq;
  trip.lastSeenAtMs = nowMs;
  trip.lat = fix.lat;
  trip.lng = fix.lng;
  trip.speedMps = fix.speedMps;
  trip.heading = fix.heading;
  trip.accuracyM = fix.accuracyM;
  trip.batteryPct = fix.batteryPct;
  trip.charging = fix.charging;
  if (fix.speedMps >= cfg.movingSpeedMps) {
    trip.movingTicks += 1;
    trip.stillTicks = 0;
  } else {
    trip.movingTicks = 0;
    if (fix.speedMps < 0.5) trip.stillTicks += 1;
    else trip.stillTicks = 0;
  }
}

/** End a trip, dropping its fix. Removes the vehicle when no member remains. */
export function endTrip(
  store: Store,
  events: EngineEvent[],
  deviceId: string,
  reason: EndReason = "user",
): void {
  const trip = store.trips.get(deviceId);
  if (!trip) return;
  const lineId = trip.lineId;
  const vehicleId = trip.vehicleId;
  store.trips.delete(deviceId);
  if (vehicleId !== null) {
    let members = 0;
    for (const t of store.trips.values()) {
      if (t.vehicleId === vehicleId) members += 1;
    }
    if (members === 0) removeVehicle(store, vehicleId);
  }
  events.push({ kind: "tripEnded", lineId, reason });
}

// Location service: fix filtering and sampling modes.
// Mirrors app/lib/features/trip/location_service.dart.
// Fixes filtered client-side and re-checked server-side.
// PRIVACY: fixes rounded before sending, never logged.
import * as Location from "expo-location";
import { FIX_ACCURACY_MAX_M } from "../../core/config/env";

export const fixArea = {
  latMin: -19.05,
  latMax: -18.4,
  lngMin: -40.25,
  lngMax: -39.55,
};

export const fixMaxAgeMs = 20000;
export const degradedAccuracyM = 40;
export const degradedHoldMs = 60 * 1000;
export const stillSpeedMaxMps = 0.5;

export interface TripFix {
  seq: number;
  lat: number;
  lng: number;
  speedMps: number;
  heading: number | null;
  accuracyM: number;
  batteryPct: number;
  charging: boolean;
  acceptedAtMs: number;
}

export interface RawFix {
  lat: number;
  lng: number;
  accuracyM: number;
  isMocked: boolean;
  timestampMs: number;
}

export function dropReason(fix: RawFix, nowMs: number): string | null {
  if (fix.isMocked) return "mocked";
  if (nowMs - fix.timestampMs > fixMaxAgeMs) return "stale";
  if (fix.accuracyM > FIX_ACCURACY_MAX_M || fix.accuracyM < 0) return "accuracy";
  if (
    fix.lat < fixArea.latMin ||
    fix.lat > fixArea.latMax ||
    fix.lng < fixArea.lngMin ||
    fix.lng > fixArea.lngMax
  ) {
    return "outside";
  }
  return null;
}

export function acceptFix(fix: RawFix, nowMs: number): boolean {
  return dropReason(fix, nowMs) === null;
}

export function normalizeSpeed(speedMps: number): number {
  if (speedMps < 0) return 0;
  return Math.round(speedMps * 10) / 10;
}

export function normalizeHeading(
  heading: number | null,
  speedMps: number,
): number | null {
  if (heading === null || heading === undefined) return null;
  if (speedMps < stillSpeedMaxMps) return null;
  if (heading === 360) return 0;
  if (heading >= 0 && heading < 360) return heading;
  return null;
}

export function round5(v: number): number {
  return Math.round(v * 100000) / 100000;
}

export function batteryBucket(pct: number): number {
  return Math.floor(pct / 5) * 5;
}

export function expoAccuracyFor(
  mode: string,
): Location.Accuracy {
  switch (mode) {
    case "leaderMoving":
    case "waiting":
      return Location.Accuracy.High;
    case "leaderStill":
    case "follower":
      return Location.Accuracy.Balanced;
    case "offlineSaver":
    case "paused":
    default:
      return Location.Accuracy.Low;
  }
}

export function intervalMsForMode(mode: string): number {
  switch (mode) {
    case "waiting":
    case "leaderMoving":
      return 5000;
    case "leaderStill":
      return 15000;
    case "follower":
    case "offlineSaver":
    case "paused":
    default:
      return 45000;
  }
}

// Fix validation and plausibility. Pure; time is a parameter.
// Server re-checks everything the client filters. See PLAN.md RF12 and 6.6.

import type { EngineConfig, Fix } from "./types.ts";

export type InvalidKind =
  | "shape"
  | "bbox"
  | "accuracy"
  | "speed"
  | "heading"
  | "battery";

/** Validate field shapes and ranges. Returns the invalid kind or null. */
export function validateFix(fix: Fix, cfg: EngineConfig): InvalidKind | null {
  if (
    !Number.isFinite(fix.lat) || !Number.isFinite(fix.lng) ||
    !Number.isFinite(fix.speedMps) || !Number.isFinite(fix.accuracyM) ||
    !Number.isFinite(fix.batteryPct) || !Number.isFinite(fix.seq)
  ) {
    return "shape";
  }
  if (
    fix.lat < cfg.bbox.latMin || fix.lat > cfg.bbox.latMax ||
    fix.lng < cfg.bbox.lngMin || fix.lng > cfg.bbox.lngMax
  ) {
    return "bbox";
  }
  if (fix.accuracyM > cfg.accuracyMaxM || fix.accuracyM < 0) return "accuracy";
  if (fix.speedMps < 0 || fix.speedMps > cfg.speedMaxMps) return "speed";
  if (
    fix.heading !== null &&
    (!Number.isFinite(fix.heading) || fix.heading < 0 || fix.heading >= 360)
  ) {
    return "heading";
  }
  if (fix.batteryPct < 0 || fix.batteryPct > 100) return "battery";
  return null;
}

/** Implied speed between two fixes in m/s. Takes the precomputed
 * distance so the caller never pays for the same haversine twice. */
export function impliedSpeedMps(
  distM: number,
  fromMs: number,
  toMs: number,
): number {
  const dtS = (toMs - fromMs) / 1000;
  if (dtS <= 0) return 0;
  return distM / dtS;
}

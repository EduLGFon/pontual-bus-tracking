// Attach-at-ping online clustering with dead reckoning. Pure.
// See ARCHITECTURE.md D04 and 6.6 step 9. Stable vehicle ids, no marker flicker.
import { attachTolM, distM, predict } from "./geo.ts";
import type { EngineConfig, Trip, Vehicle } from "./types.ts";

/** Predicted vehicle position, age capped at 60 s. */
export function predictedVehicle(
  v: Vehicle,
  nowMs: number,
): { lat: number; lng: number; ageS: number } {
  const ageS = Math.min(60, Math.max(0, (nowMs - v.fixAtMs) / 1000));
  const headingRad = v.heading === null ? null : (v.heading * Math.PI) / 180;
  const p = predict(v.lat, v.lng, v.speedMps, headingRad, ageS);
  return { ...p, ageS };
}

/** Find the nearest attachable vehicle of the same line. */
export function nearestVehicle(
  vehicles: Vehicle[],
  lineId: number,
  lat: number,
  lng: number,
  speedMps: number,
  nowMs: number,
  cfg: EngineConfig,
): Vehicle | null {
  let best: Vehicle | null = null;
  let bestD = Infinity;
  for (const v of vehicles) {
    if (v.lineId !== lineId) continue;
    const p = predictedVehicle(v, nowMs);
    const tol = attachTolM(
      cfg.attachBaseTolM,
      cfg.attachSpeedFactor,
      cfg.attachTolMaxM,
      speedMps,
      p.ageS,
    );
    const extra = v.heading === null ? speedMps * p.ageS : 0;
    const d = distM(lat, lng, p.lat, p.lng);
    if (d <= tol + extra && d < bestD) {
      best = v;
      bestD = d;
    }
  }
  return best;
}

/** Coherence check of an attached trip against its vehicle prediction. */
export function isCoherent(
  trip: Trip,
  vehicle: Vehicle,
  nowMs: number,
  cfg: EngineConfig,
): boolean {
  const p = predictedVehicle(vehicle, nowMs);
  const tol = attachTolM(
    cfg.attachBaseTolM,
    cfg.attachSpeedFactor,
    cfg.attachTolMaxM,
    trip.speedMps,
    p.ageS,
  );
  return distM(trip.lat, trip.lng, p.lat, p.lng) <= tol;
}

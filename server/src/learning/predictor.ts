// ETA prediction from current pace + historic aggregates.
// See docs/data-learning.md section 5.5.
import { distM } from "../domain/geo.ts";
import type { LearningConsumer } from "./consumer.ts";
import type { LearningConfig } from "./types.ts";

export interface EtaResult {
  etaS: number;
  confidence: "high" | "medium" | "low";
  sampleCount: number;
  method: string;
}

interface Pt {
  lat: number;
  lng: number;
}

interface RouteGeometry {
  pts: Pt[];
  /** Cumulative distance from the route start to each vertex, in metres. */
  cumM: number[];
}

/** Below this pace the bus is stopped, so use the default speed instead. */
const MOVING_SPEED_THRESHOLD_MPS = 1.5;
/** A target this far behind the vehicle is clearly passed. */
const PASSED_TOLERANCE_M = 30;
/** Last-resort speed when the configured default is unusable. */
const FALLBACK_SPEED_MPS = 6;

function hourBucket(ms: number): number {
  const d = new Date(ms - 3 * 3600 * 1000);
  return d.getUTCHours() * 4 + Math.floor(d.getUTCMinutes() / 15);
}

function dayOfWeek(ms: number): number {
  const d = new Date(ms - 3 * 3600 * 1000);
  return d.getUTCDay();
}

function usableSpeed(value: number, fallback: number): number {
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

/**
 * Build cumulative route distances once so progress, partial legs and the
 * passed check all use distance along the route rather than a single
 * polyline segment.
 */
function routeGeometry(
  routePts: Array<{ lat: number; lng: number }>,
): RouteGeometry | null {
  const pts = routePts.filter((p) =>
    Number.isFinite(p.lat) && Number.isFinite(p.lng)
  );
  if (pts.length < 2) return null;
  const cumM = [0];
  for (let i = 1; i < pts.length; i++) {
    const d = distM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    if (!Number.isFinite(d) || d < 0) return null;
    cumM.push(cumM[i - 1] + d);
  }
  // A zero-length route carries no progress information.
  return cumM[cumM.length - 1] > 0 ? { pts, cumM } : null;
}

/**
 * Distance from the route start to the nearest point on the polyline. The
 * projection matches distToPolylineM, but returns cumulative progress so a
 * stop between two sparse vertices keeps its true along-route position.
 */
function snapAlongM(
  lat: number,
  lng: number,
  geo: RouteGeometry,
): number | null {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  let bestAlongM: number | null = null;
  let bestM = Infinity;
  for (let i = 0; i + 1 < geo.pts.length; i++) {
    const a = geo.pts[i];
    const b = geo.pts[i + 1];
    const kx = 111320 * Math.cos(((a.lat + b.lat) / 2 * Math.PI) / 180);
    const px = (lng - a.lng) * kx;
    const py = (lat - a.lat) * 111320;
    const bx = (b.lng - a.lng) * kx;
    const by = (b.lat - a.lat) * 111320;
    const len2 = bx * bx + by * by;
    let t = len2 === 0 ? 0 : (px * bx + py * by) / len2;
    t = Math.max(0, Math.min(1, t));
    const d = Math.hypot(px - t * bx, py - t * by);
    if (!Number.isFinite(d)) continue;
    if (d < bestM) {
      bestM = d;
      bestAlongM = geo.cumM[i] +
        t * (geo.cumM[i + 1] - geo.cumM[i]);
    }
  }
  return bestAlongM;
}

/**
 * Current pace is only trustworthy while the bus is moving. A stopped bus
 * reports a near-zero pace, which must not turn a short leg into a crawl.
 */
function effectiveSpeedMps(
  paceMps: number,
  config: LearningConfig,
): number {
  if (Number.isFinite(paceMps) && paceMps >= MOVING_SPEED_THRESHOLD_MPS) {
    return paceMps;
  }
  return usableSpeed(config.defaultSpeedMps, FALLBACK_SPEED_MPS);
}

function secondsFor(distanceM: number, speedMps: number): number {
  if (!Number.isFinite(distanceM) || distanceM <= 0) return 0;
  const etaS = distanceM / speedMps;
  return Number.isFinite(etaS) && etaS > 0 ? Math.round(etaS) : 0;
}

/** Honest straight-line estimate when no usable route geometry exists. */
function fallbackDistance(
  config: LearningConfig,
  vehicleLat: number,
  vehicleLng: number,
  target: Pt,
): EtaResult {
  const speedMps = usableSpeed(config.defaultSpeedMps, FALLBACK_SPEED_MPS);
  const distanceM = distM(vehicleLat, vehicleLng, target.lat, target.lng);
  return {
    etaS: secondsFor(distanceM, speedMps),
    confidence: "low",
    sampleCount: 0,
    method: "fallback_distance",
  };
}

export async function predictEta(
  consumer: LearningConsumer,
  config: LearningConfig,
  lineId: number,
  direction: number,
  vehicleLat: number,
  vehicleLng: number,
  vehiclePaceMps: number,
  stopId: string,
  stops: Array<{ id: string; lat: number; lng: number }>,
  routePts: Array<{ lat: number; lng: number }>,
  nowMs: number,
): Promise<EtaResult> {
  const now = Number.isFinite(nowMs) ? nowMs : 0;
  const hb = hourBucket(now);
  const dow = dayOfWeek(now);
  const target = stops.find((s) => s.id === stopId);
  const geo = routeGeometry(routePts);

  if (!geo) {
    // No usable route: the straight-line distance is the honest answer. It
    // is still useful for a line with no learned corridor, and must never
    // collapse to zero or "passed" just because the polyline is missing.
    return target ? fallbackDistance(config, vehicleLat, vehicleLng, target) : {
      etaS: 0,
      confidence: "low",
      sampleCount: 0,
      method: "fallback_distance",
    };
  }

  const vehicleAlongM = snapAlongM(vehicleLat, vehicleLng, geo);
  if (vehicleAlongM === null || !target) {
    return {
      etaS: 0,
      confidence: "low",
      sampleCount: 0,
      method: "fallback",
    };
  }

  const snappedStops = stops.flatMap((s) => {
    const alongM = snapAlongM(s.lat, s.lng, geo);
    return alongM === null ? [] : [{ ...s, alongM }];
  }).sort((a, b) => a.alongM - b.alongM);
  const targetIdx = snappedStops.findIndex((s) => s.id === stopId);
  if (targetIdx < 0) {
    // The target's coordinates are unusable for snapping; fall back to the
    // straight-line distance rather than losing the estimate.
    return fallbackDistance(config, vehicleLat, vehicleLng, target);
  }
  const targetAlongM = snappedStops[targetIdx].alongM;

  if (vehicleAlongM > targetAlongM + PASSED_TOLERANCE_M) {
    return { etaS: 0, confidence: "low", sampleCount: 0, method: "passed" };
  }

  const nextIdx = snappedStops.findIndex((s) => s.alongM > vehicleAlongM);
  if (nextIdx < 0 || nextIdx > targetIdx) {
    // The vehicle is at the target, or behind it by less than the passed
    // tolerance: there is no remaining route leg to price.
    return { etaS: 0, confidence: "low", sampleCount: 0, method: "learned" };
  }

  const speedMps = effectiveSpeedMps(vehiclePaceMps, config);
  const defaultSpeedMps = usableSpeed(
    config.defaultSpeedMps,
    FALLBACK_SPEED_MPS,
  );
  const defaultDwellS = Number.isFinite(config.defaultDwellS) &&
      config.defaultDwellS >= 0
    ? config.defaultDwellS
    : 0;
  // Partial leg runs from the snapped vehicle position to the next stop
  // ahead, not just to the end of the nearest polyline vertex.
  let totalS = Math.max(0, snappedStops[nextIdx].alongM - vehicleAlongM) /
    speedMps;
  let sampleCount = 0;
  let fallbacks = 0;

  for (let i = nextIdx; i <= targetIdx; i++) {
    const curStop = snappedStops[i];
    if (i > nextIdx) {
      const prevStop = snappedStops[i - 1];
      const seg = await consumer.segmentStats(
        lineId,
        direction,
        prevStop.id,
        curStop.id,
        hb,
        dow,
      );
      // The consumer read helpers return any row with at least one sample,
      // so a one-pass segment is valid evidence here. Only presence matters.
      if (
        seg && Number.isFinite(seg.p50) && seg.p50 >= 0 &&
        Number.isFinite(seg.count) && seg.count >= 1
      ) {
        const histSpeedMps = Number.isFinite(seg.distanceM) &&
            seg.distanceM > 0
          ? seg.distanceM / Math.max(seg.p50, 1)
          : speedMps;
        // The historical rate is compared against the same effective speed
        // as the partial leg, so a stopped bus does not get a maxed factor.
        const factor = Math.max(
          0.5,
          Math.min(2.0, histSpeedMps / speedMps),
        );
        totalS += seg.p50 * factor;
        sampleCount += seg.count;
      } else {
        const d = distM(prevStop.lat, prevStop.lng, curStop.lat, curStop.lng);
        const segmentM = Number.isFinite(d) && d > 0
          ? d
          : Math.max(0, curStop.alongM - prevStop.alongM);
        totalS += segmentM / defaultSpeedMps;
        fallbacks += 1;
      }
    }
    // Dwell at intermediate stops only; the target stop ends the trip.
    if (i < targetIdx) {
      const dw = await consumer.dwellStats(curStop.id, hb, dow);
      // Same one-sample rule as segmentStats above.
      if (
        dw && Number.isFinite(dw.p50) && dw.p50 >= 0 &&
        Number.isFinite(dw.count) && dw.count >= 1
      ) {
        totalS += dw.p50;
        sampleCount += dw.count;
      } else {
        totalS += defaultDwellS;
        fallbacks += 1;
      }
    }
  }

  const confidence: "high" | "medium" | "low" = fallbacks === 0
    ? "high"
    : fallbacks <= 2
    ? "medium"
    : "low";
  return {
    etaS: Number.isFinite(totalS) && totalS > 0
      ? Math.max(0, Math.round(totalS))
      : 0,
    confidence,
    sampleCount,
    method: "learned",
  };
}

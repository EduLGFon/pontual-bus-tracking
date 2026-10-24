// ETA prediction from current pace + historic aggregates.
// See docs/data-learning.md section 6.5.
import { distM } from "../domain/geo.ts";
import type { LearningConsumer } from "./consumer.ts";
import type { LearningConfig } from "./types.ts";

export interface EtaResult {
  etaS: number;
  confidence: "high" | "medium" | "low";
  sampleCount: number;
  method: string;
}

function hourBucket(ms: number): number {
  const d = new Date(ms - 3 * 3600 * 1000);
  return d.getUTCHours() * 4 + Math.floor(d.getUTCMinutes() / 15);
}

function dayOfWeek(ms: number): number {
  const d = new Date(ms - 3 * 3600 * 1000);
  return d.getUTCDay();
}

function snapProgress(
  lat: number,
  lng: number,
  pts: Array<{ lat: number; lng: number }>,
): { progress: number; distanceToNext: number } {
  if (pts.length < 2) return { progress: 0, distanceToNext: 0 };
  // cumulative distances
  const cum: number[] = [0];
  for (let i = 1; i < pts.length; i++) {
    cum.push(
      cum[i - 1] +
        distM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng),
    );
  }
  const total = cum[cum.length - 1];
  // find nearest segment
  let bestI = 0;
  let bestD = Infinity;
  let bestT = 0;
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1];
    const kx = 111320 * Math.cos(((a.lat + b.lat) / 2 * Math.PI) / 180);
    const px = (lng - a.lng) * kx;
    const py = (lat - a.lat) * 111320;
    const bx = (b.lng - a.lng) * kx;
    const by = (b.lat - a.lat) * 111320;
    const len2 = bx * bx + by * by;
    let t = len2 === 0 ? 0 : (px * bx + py * by) / len2;
    t = Math.max(0, Math.min(1, t));
    const cx = t * bx;
    const cy = t * by;
    const d = Math.hypot(px - cx, py - cy);
    if (d < bestD) {
      bestD = d;
      bestI = i;
      bestT = t;
    }
  }
  const segStart = cum[bestI];
  const segLen = cum[bestI + 1] - cum[bestI];
  const progress = total === 0 ? 0 : (segStart + bestT * segLen) / total;
  const remainingInSeg = (1 - bestT) * segLen;
  return { progress, distanceToNext: remainingInSeg };
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
  const hb = hourBucket(nowMs);
  const dow = dayOfWeek(nowMs);
  const { progress, distanceToNext } = snapProgress(
    vehicleLat,
    vehicleLng,
    routePts,
  );
  // order stops by progress along route (already by ordinal typically)
  const stopProgress = stops.map((s) => {
    const { progress: p } = snapProgress(s.lat, s.lng, routePts);
    return { ...s, progress: p };
  }).sort((a, b) => a.progress - b.progress);

  const targetIdx = stopProgress.findIndex((s) => s.id === stopId);
  if (targetIdx < 0) {
    return {
      etaS: distanceToNext / Math.max(vehiclePaceMps, 1),
      confidence: "low",
      sampleCount: 0,
      method: "fallback",
    };
  }
  // find next stop at progress > vehicle progress
  let nextIdx = stopProgress.findIndex((s) => s.progress > progress);
  if (nextIdx < 0) nextIdx = stopProgress.length; // past last
  if (nextIdx > targetIdx) {
    // vehicle already past target
    return { etaS: 0, confidence: "low", sampleCount: 0, method: "passed" };
  }
  if (nextIdx === stopProgress.length) {
    nextIdx = Math.max(0, stopProgress.length - 1);
  }

  let totalS = distanceToNext / Math.max(vehiclePaceMps, 1);
  let sampleCount = 0;
  let fallbacks = 0;
  const speeds: number[] = [];

  for (let i = nextIdx; i <= targetIdx; i++) {
    const curStop = stopProgress[i];
    if (i > nextIdx) {
      // segment from previous stop to curStop
      const prevStop = stopProgress[i - 1];
      const seg = await consumer.segmentStats(
        lineId,
        direction,
        prevStop.id,
        curStop.id,
        hb,
        dow,
      );
      if (seg && seg.count >= config.kMin) {
        const histSpeed = seg.distanceM / Math.max(seg.p50, 1);
        const factor = Math.max(
          0.5,
          Math.min(2.0, histSpeed / Math.max(vehiclePaceMps, 1)),
        );
        totalS += seg.p50 * factor;
        sampleCount += seg.count;
        speeds.push(histSpeed);
      } else {
        const d = distM(prevStop.lat, prevStop.lng, curStop.lat, curStop.lng);
        totalS += d / Math.max(config.defaultSpeedMps, 1);
        fallbacks += 1;
      }
    }
    // dwell at curStop (except final? include dwell at intermediate; for target, maybe exclude? include)
    if (i < targetIdx) {
      const dw = await consumer.dwellStats(curStop.id, hb, dow);
      if (dw && dw.count >= config.kMin) {
        totalS += dw.p50;
        sampleCount += dw.count;
      } else {
        totalS += config.defaultDwellS;
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
    etaS: Math.max(0, Math.round(totalS)),
    confidence,
    sampleCount,
    method: "learned",
  };
}

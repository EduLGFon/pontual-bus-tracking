// Pure geographic helpers for place search. Mirrors app/lib/core/geo/route_proximity.dart.
import { distanceM } from "./geo";
import type { LatLng } from "./geo";

export interface RouteEntryLike {
  points: LatLng[];
  stops: { lat: number; lng: number }[];
}

export function minDistanceToPolylineM(point: LatLng, polyline: LatLng[]): number {
  if (polyline.length < 2) {
    if (polyline.length === 1) {
      return distanceM(point, polyline[0]);
    }
    return Infinity;
  }
  let best = Infinity;
  for (let i = 0; i < polyline.length - 1; i++) {
    const d = pointToSegmentM(point, polyline[i], polyline[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

function pointToSegmentM(p: LatLng, a: LatLng, b: LatLng): number {
  const mPerDegLat = 111320.0;
  const midLat = (a.lat + b.lat) / 2;
  const mPerDegLng = 111320.0 * Math.cos((midLat * Math.PI) / 180.0);
  const ax = a.lng * mPerDegLng;
  const ay = a.lat * mPerDegLat;
  const bx = b.lng * mPerDegLng;
  const by = b.lat * mPerDegLat;
  const px = p.lng * mPerDegLng;
  const py = p.lat * mPerDegLat;
  const vx = bx - ax;
  const vy = by - ay;
  const wx = px - ax;
  const wy = py - ay;
  const len2 = vx * vx + vy * vy;
  let t = len2 === 0 ? 0 : (wx * vx + wy * vy) / len2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  const cx = ax + t * vx;
  const cy = ay + t * vy;
  const dx = px - cx;
  const dy = py - cy;
  return Math.sqrt(dx * dx + dy * dy);
}

export function minDistanceToStopsM(point: LatLng, stops: LatLng[]): number {
  if (stops.length === 0) return Infinity;
  let best = Infinity;
  for (const s of stops) {
    const d = distanceM(point, s);
    if (d < best) best = d;
  }
  return best;
}

export function linePassesNear(opts: {
  place: LatLng;
  entry: RouteEntryLike;
  routeRadiusM?: number;
  stopRadiusM?: number;
}): boolean {
  const routeRadiusM = opts.routeRadiusM ?? 500;
  const stopRadiusM = opts.stopRadiusM ?? 300;
  const routeD = minDistanceToPolylineM(opts.place, opts.entry.points);
  if (routeD <= routeRadiusM) return true;
  const stopPoints: LatLng[] = opts.entry.stops.map((s) => ({ lat: s.lat, lng: s.lng }));
  const stopD = minDistanceToStopsM(opts.place, stopPoints);
  return stopD <= stopRadiusM;
}

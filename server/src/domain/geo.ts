// Pure geo helpers. No I/O, no clock. See PLAN.md 6.6.
// Units carry suffixes: distM, speedMps, dtS.

const EARTH_M = 6371000;
const DEG_M = 111320;

/** Haversine distance in meters. */
export function distM(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_M * Math.asin(Math.sqrt(a));
}

export interface Predicted {
  lat: number;
  lng: number;
}

/**
 * Dead reckoning (equirectangular, fine at city scale). Heading h is radians
 * clockwise from north. Null heading keeps position; callers widen tolerance
 * by v*dt. See PLAN.md 6.6.
 */
export function predict(
  lat: number,
  lng: number,
  speedMps: number,
  heading: number | null,
  dtS: number,
): Predicted {
  if (heading === null || speedMps <= 0 || dtS <= 0) return { lat, lng };
  const d = speedMps * dtS;
  const lat2 = lat + (d * Math.cos(heading)) / DEG_M;
  const lng2 = lng +
    (d * Math.sin(heading)) / (DEG_M * Math.cos((lat * Math.PI) / 180));
  return { lat: lat2, lng: lng2 };
}

/** Attach tolerance: min(max, base + factor * speed * age). */
export function attachTolM(
  baseTolM: number,
  speedFactor: number,
  tolMaxM: number,
  speedMps: number,
  ageS: number,
): number {
  return Math.min(tolMaxM, baseTolM + speedFactor * speedMps * ageS);
}

function distToSegM(
  lat: number,
  lng: number,
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const kx = DEG_M * Math.cos(((aLat + bLat) / 2 * Math.PI) / 180);
  const px = (lng - aLng) * kx;
  const py = (lat - aLat) * DEG_M;
  const ax = 0;
  const ay = 0;
  const bx = (bLng - aLng) * kx;
  const by = (bLat - aLat) * DEG_M;
  const dx = bx - ax;
  const dy = by - ay;
  const len2 = dx * dx + dy * dy;
  let t = len2 === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + t * dx;
  const cy = ay + t * dy;
  return Math.hypot(px - cx, py - cy);
}

/** Distance to a polyline in meters. Linear scan; routes are small. */ export function distToPolylineM(
  lat: number,
  lng: number,
  polyline: { lat: number; lng: number }[],
): number {
  if (polyline.length === 0) return Infinity;
  if (polyline.length === 1) {
    return distM(lat, lng, polyline[0].lat, polyline[0].lng);
  }
  let best = Infinity;
  for (let i = 0; i + 1 < polyline.length; i++) {
    const d = distToSegM(
      lat,
      lng,
      polyline[i].lat,
      polyline[i].lng,
      polyline[i + 1].lat,
      polyline[i + 1].lng,
    );
    if (d < best) best = d;
  }
  return best;
}

/**
 * Decode a Google polyline at the given precision. Mirrors the data route
 * tool (tools/route/main.ts); kept in sync by the round-trip test.
 */
export function decodePolyline(
  text: string,
  precision = 5,
): { lat: number; lng: number }[] {
  const factor = 10 ** precision;
  const pts: { lat: number; lng: number }[] = [];
  let lat = 0;
  let lng = 0;
  let i = 0;
  while (i < text.length) {
    let shift = 0;
    let delta = 0;
    let b: number;
    do {
      b = text.charCodeAt(i++) - 63;
      delta |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    lat += delta & 1 ? ~(delta >> 1) : delta >> 1;
    shift = 0;
    delta = 0;
    do {
      b = text.charCodeAt(i++) - 63;
      delta |= (b & 31) << shift;
      shift += 5;
    } while (b >= 32);
    lng += delta & 1 ? ~(delta >> 1) : delta >> 1;
    pts.push({ lat: lat / factor, lng: lng / factor });
  }
  return pts;
}

/** Route geometry with a precomputed bounding box. The box is built once
 * at bundle load so the per-ping route check can reject far fixes without
 * scanning every segment. See distToShapeM. */
export interface RouteShape {
  pts: { lat: number; lng: number }[];
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

/** Wrap decoded points with their bounding box. Empty input yields an
 * empty shape; distToShapeM answers Infinity for it, matching
 * distToPolylineM. */
export function routeShape(
  pts: { lat: number; lng: number }[],
): RouteShape {
  let minLat = Infinity;
  let maxLat = -Infinity;
  let minLng = Infinity;
  let maxLng = -Infinity;
  for (const p of pts) {
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
    if (p.lng < minLng) minLng = p.lng;
    if (p.lng > maxLng) maxLng = p.lng;
  }
  return { pts, minLat, maxLat, minLng, maxLng };
}

/** Distance to a route shape in meters. Fixes farther than [maxM] from
 * the bounding box edge skip the segment scan: the edge distance is a
 * lower bound on the true distance (same equirectangular projection as
 * distToSegM), so returning it is exact for the `> maxM` comparison the
 * single caller makes. Fixes near or inside the box pay the full scan. */
export function distToShapeM(
  lat: number,
  lng: number,
  shape: RouteShape,
  maxM: number,
): number {
  if (shape.pts.length === 0) return Infinity;
  const kx = DEG_M * Math.cos((lat * Math.PI) / 180);
  const dx = lat < shape.minLat
    ? (shape.minLat - lat) * DEG_M
    : lat > shape.maxLat
    ? (lat - shape.maxLat) * DEG_M
    : 0;
  const dw = lng < shape.minLng
    ? (shape.minLng - lng) * kx
    : lng > shape.maxLng
    ? (lng - shape.maxLng) * kx
    : 0;
  if (dx > maxM || dw > maxM) return Math.hypot(dx, dw);
  const edge = Math.hypot(dx, dw);
  if (edge > maxM) return edge;
  return distToPolylineM(lat, lng, shape.pts);
}


/** Encode a list of lat/lng points as a Google polyline at the given
 * precision. Mirrors tools/route/main.ts. */
export function encodePolyline(
  pts: { lat: number; lng: number }[],
  precision = 5,
): string {
  const factor = 10 ** precision;
  let prevLat = 0;
  let prevLng = 0;
  let out = "";
  for (const p of pts) {
    const lat = Math.round(p.lat * factor);
    const lng = Math.round(p.lng * factor);
    out += encodeSigned(lat - prevLat);
    out += encodeSigned(lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return out;
}

function encodeSigned(n: number): string {
  let v = n < 0 ? ~(n << 1) : n << 1;
  let out = "";
  while (v >= 0x20) {
    out += String.fromCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out += String.fromCharCode(v + 63);
  return out;
}

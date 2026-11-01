// Geo helpers. Mirrors app/lib/core/geo/geo.dart.
export interface LatLng {
  lat: number;
  lng: number;
}

export function distanceM(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
}

export function inBoundingBox(
  p: { lat: number; lng: number },
  minLat: number,
  minLng: number,
  maxLat: number,
  maxLng: number,
): boolean {
  return (
    p.lat >= minLat && p.lat <= maxLat && p.lng >= minLng && p.lng <= maxLng
  );
}

export function decodePolyline(text: string, precision = 5): LatLng[] {
  const factor = Math.pow(10, precision);
  const points: LatLng[] = [];
  let lat = 0;
  let lng = 0;
  let i = 0;
  const readDelta = (): number => {
    let delta = 0;
    let multiplier = 1;
    let b = 0;
    do {
      b = text.charCodeAt(i++) - 63;
      delta += (b % 32) * multiplier;
      multiplier *= 32;
    } while (b >= 32);
    return delta % 2 !== 0 ? -Math.floor(delta / 2) - 1 : Math.floor(delta / 2);
  };
  while (i < text.length) {
    lat += readDelta();
    lng += readDelta();
    points.push({ lat: lat / factor, lng: lng / factor });
  }
  return points;
}

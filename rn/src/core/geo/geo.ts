// Geo helpers. Mirrors app/lib/core/geo/geo.dart (minimal).
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

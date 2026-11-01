// Coarse report areas. Mirrors app/lib/domain/reporting/report_area.dart.
const reportCellM = 150;
const reportRefLat = -18.7;
const latStep = reportCellM / 111320;
const lngStep = reportCellM / (111320 * Math.cos((reportRefLat * Math.PI) / 180));
const areaIdRe = /^g(\d{1,6})_(\d{1,7})$/;

export interface ReportAreaCenter {
  lat: number;
  lng: number;
}

export function reportAreaOf(lat: number, lng: number): string {
  const latIdx = Math.floor((lat + 90) / latStep);
  const lngIdx = Math.floor((lng + 180) / lngStep);
  return `g${latIdx}_${lngIdx}`;
}

export function reportAreaCenterOf(areaId: string): ReportAreaCenter | null {
  const m = areaIdRe.exec(areaId);
  if (!m) return null;
  const latIdx = Number(m[1]);
  const lngIdx = Number(m[2]);
  if (!Number.isFinite(latIdx) || !Number.isFinite(lngIdx)) return null;
  return {
    lat: (latIdx + 0.5) * latStep - 90,
    lng: (lngIdx + 0.5) * lngStep - 180,
  };
}

export function isValidReportArea(areaId: string): boolean {
  return areaIdRe.test(areaId);
}

export const servedLatMin = -19.05;
export const servedLatMax = -18.4;
export const servedLngMin = -40.25;
export const servedLngMax = -39.55;

export function isReportAreaInServedBBox(areaId: string): boolean {
  const c = reportAreaCenterOf(areaId);
  if (!c) return false;
  return (
    c.lat >= servedLatMin - latStep &&
    c.lat <= servedLatMax + latStep &&
    c.lng >= servedLngMin - lngStep &&
    c.lng <= servedLngMax + lngStep
  );
}

export function reportAreaDistanceM(areaId: string, lat: number, lng: number): number | null {
  const c = reportAreaCenterOf(areaId);
  if (!c) return null;
  const rad = Math.PI / 180;
  const dLat = (c.lat - lat) * rad;
  const dLng = (c.lng - lng) * rad;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat * rad) * Math.cos(c.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(a));
}

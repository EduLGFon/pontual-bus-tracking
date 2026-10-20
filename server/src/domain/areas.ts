// Coarse report areas. A report carries a grid cell of about 150 m, never
// a coordinate. The client computes the cell on-device; the server only
// validates the id and stores it in memory for the report TTL.
// PRIVACY: a cell is approximate presence, not a position. Never log it.
// See DECISIONS.md#D83 and PLAN.md 6.6.
import { defaultEngineConfig } from "./types.ts";

/** Cell edge in meters. */
export const REPORT_CELL_M = 150;

/** Reference latitude for the longitude step. Fixed for the served area. */
export const REPORT_REF_LAT = -18.7;

const LAT_STEP = REPORT_CELL_M / 111320;
const LNG_STEP = REPORT_CELL_M /
  (111320 * Math.cos((REPORT_REF_LAT * Math.PI) / 180));
const AREA_ID = /^g(\d{1,6})_(\d{1,7})$/;

/** Approximate center of one cell. */
export interface AreaCenter {
  lat: number;
  lng: number;
}

/** Grid cell id for a coordinate. Mirrors the Dart implementation. */
export function areaIdOf(lat: number, lng: number): string {
  const latIdx = Math.floor((lat + 90) / LAT_STEP);
  const lngIdx = Math.floor((lng + 180) / LNG_STEP);
  return `g${latIdx}_${lngIdx}`;
}

/** Decodes a cell id to its approximate center, or null when malformed. */
export function areaCenter(areaId: string): AreaCenter | null {
  const match = AREA_ID.exec(areaId);
  if (!match) return null;
  const latIdx = Number(match[1]);
  const lngIdx = Number(match[2]);
  if (!Number.isSafeInteger(latIdx) || !Number.isSafeInteger(lngIdx)) {
    return null;
  }
  return {
    lat: (latIdx + 0.5) * LAT_STEP - 90,
    lng: (lngIdx + 0.5) * LNG_STEP - 180,
  };
}

/** True when [areaId] is a well-formed grid cell. */
export function isValidAreaId(areaId: string): boolean {
  return AREA_ID.test(areaId);
}

/**
 * True when the cell center is inside the served area, with one cell of
 * margin so a report at the municipal edge is not rejected.
 */
export function isAreaInServedBBox(areaId: string): boolean {
  const center = areaCenter(areaId);
  if (center === null) return false;
  const bbox = defaultEngineConfig().bbox;
  const latMargin = LAT_STEP;
  const lngMargin = LNG_STEP;
  return center.lat >= bbox.latMin - latMargin &&
    center.lat <= bbox.latMax + latMargin &&
    center.lng >= bbox.lngMin - lngMargin &&
    center.lng <= bbox.lngMax + lngMargin;
}

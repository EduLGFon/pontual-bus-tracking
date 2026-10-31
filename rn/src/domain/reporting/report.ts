// Report kinds. Mirrors app/lib/domain/reporting/report_kind.dart.
export type ReportKindWire = "waiting" | "full" | "broken" | "blocked";
export const ReportKind = {
  waiting: "waiting",
  full: "full",
  broken: "broken",
  blocked: "blocked",
  unknown: "unknown",
} as const;
export type ReportKind = (typeof ReportKind)[keyof typeof ReportKind];

export function reportKindFromWire(w: string): ReportKind {
  if (w === "waiting" || w === "full" || w === "broken" || w === "blocked")
    return w as ReportKind;
  return ReportKind.unknown;
}

// Report area hashing (~150m grid). Mirrors app/lib/domain/reporting/report_area.dart.
const REPORT_CELL_M = 150;
const LAT_STEP = REPORT_CELL_M / 111320;
const LNG_STEP = REPORT_CELL_M / (111320 * Math.cos((-18.7 * Math.PI) / 180));

export function reportArea(lat: number, lng: number): string {
  const latIdx = Math.floor((lat + 90) / LAT_STEP);
  const lngIdx = Math.floor((lng + 180) / LNG_STEP);
  return `g${latIdx}_${lngIdx}`;
}

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
export function reportArea(lat: number, lng: number): string {
  const cell = 0.0015; // ~150m
  const la = Math.floor(lat / cell);
  const ln = Math.floor(lng / cell);
  return `${la}:${ln}`;
}

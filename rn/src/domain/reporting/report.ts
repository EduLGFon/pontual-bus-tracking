// Report kinds and area hashing. Mirrors app/lib/domain/reporting/*.dart.
import { reportAreaOf } from "./reportArea";
export type ReportKindWire = "waiting" | "full" | "broken" | "blocked";
export const ReportKind = {
  waiting: "waiting",
  full: "full",
  broken: "broken",
  blocked: "blocked",
  unknown: "unknown",
} as const;
// eslint-disable-next-line @typescript-eslint/no-redeclare
export type ReportKind = (typeof ReportKind)[keyof typeof ReportKind];

export function reportKindFromWire(w: string): ReportKind {
  if (w === "waiting" || w === "full" || w === "broken" || w === "blocked") return w as ReportKind;
  return ReportKind.unknown;
}

export function reportArea(lat: number, lng: number): string {
  return reportAreaOf(lat, lng);
}

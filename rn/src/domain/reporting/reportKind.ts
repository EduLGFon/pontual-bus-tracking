// Passenger report kinds. Mirrors app/lib/domain/reporting/report_kind.dart.
export type ReportKind = "waiting" | "full" | "broken" | "blocked" | "unknown";

export function reportKindFromWire(value: string | null | undefined): ReportKind {
  switch (value) {
    case "waiting":
    case "full":
    case "broken":
    case "blocked":
      return value;
    default:
      return "unknown";
  }
}

export function reportKindWire(k: ReportKind): string {
  return k;
}

export function isPresence(k: ReportKind): boolean {
  return k === "waiting";
}
export function requiresArea(k: ReportKind): boolean {
  return k === "waiting" || k === "blocked";
}
export function usesLocation(k: ReportKind): boolean {
  return requiresArea(k);
}
export function isKnown(k: ReportKind): boolean {
  return k !== "unknown";
}

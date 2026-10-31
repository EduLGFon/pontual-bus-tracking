// Reports adapter. Port of app/lib/ui/adapters/reports_adapter.dart.
import type { ReportKind } from "../../domain/reporting/reportKind";

export function reportSeverity(kind: ReportKind): number {
  switch (kind) {
    case "blocked":
      return 0;
    case "broken":
      return 1;
    case "full":
      return 2;
    case "waiting":
      return 3;
    default:
      return 4;
  }
}
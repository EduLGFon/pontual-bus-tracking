// Report styling: labels per kind. Port of
// app/lib/ui/features/reports/report_style.dart.
import type { ReportKind } from "../../../domain/reporting/reportKind";

/** Ghost action label on the line sheet (PLAN.md S15). No uiStrings key. */
export const reportActionLabel = "Sinalizar";

export function reportLabel(kind: ReportKind): string {
  switch (kind) {
    case "waiting":
      return "Ainda esperando";
    case "full":
      return "Ônibus lotado";
    case "broken":
      return "Ônibus quebrado";
    case "blocked":
      return "Acesso bloqueado";
    default:
      return "Sinalização";
  }
}

/** Row text that never exposes a single person as a number. */
export function reportCountText(kind: ReportKind, count: number): string {
  if (kind === "waiting") {
    if (count <= 1) return "Alguém está esperando aqui";
    return `${count} pessoas esperando`;
  }
  if (count <= 1) return "1 relato recente";
  return `${count} pessoas relataram`;
}

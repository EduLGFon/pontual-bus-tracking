// Reports providers. Port of app/lib/ui/features/reports/reports_providers.dart.
// Reports ride on the vehicles snapshot (field `r`); this hook converts them
// to view models sorted by severity.
import { useMemo } from "react";
import type { ReportDTO } from "../../../data/api/dto";
import { reportKindFromWire } from "../../../domain/reporting/reportKind";
import { reportSeverity } from "../../adapters/reports_adapter";
import type { ReportVM } from "../../models/report_vm";

export function reportsOf(snapshot: { r?: ReportDTO[] } | null, lineId: number): ReportVM[] {
  const rows = snapshot?.r ?? [];
  const vms: ReportVM[] = rows.map((d) => ({
    lineId,
    kind: reportKindFromWire(d.kind),
    area: d.area ?? null,
    count: d.count,
    createdAgeS: d.created_age_s,
    updatedAgeS: d.updated_age_s,
    expiresInS: d.expires_in_s,
    distanceM: null,
  }));
  return vms
    .filter((v) => v.kind !== "unknown")
    .sort((a, b) => reportSeverity(a.kind) - reportSeverity(b.kind));
}

export function useReports(snapshot: { r?: ReportDTO[] } | null, lineId: number): ReportVM[] {
  return useMemo(() => reportsOf(snapshot, lineId), [snapshot, lineId]);
}

// Report view model. Port of app/lib/ui/models/report_vm.dart.
import type { ReportKind } from "../../domain/reporting/reportKind";

export interface ReportVM {
  lineId: number;
  kind: ReportKind;
  area?: string | null;
  count: number;
  createdAgeS: number;
  updatedAgeS: number;
  expiresInS: number;
  distanceM?: number | null;
}

export function reportVMKey(r: ReportVM): string {
  return `${r.lineId}:${r.kind}:${r.area ?? "-"}`;
}

export function reportVMIsExpired(r: ReportVM): boolean {
  return r.expiresInS <= 0;
}

export function reportVMIsPresence(r: ReportVM): boolean {
  return r.kind === "waiting";
}
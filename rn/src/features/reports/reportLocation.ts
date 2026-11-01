// Report location: one-shot fix converted on-device to a ~150 m cell.
// Mirrors app/lib/features/reports/report_location.dart.
// PRIVACY: exact coordinates never leave this module.
import * as Location from "expo-location";
import { reportAreaOf, isReportAreaInServedBBox } from "../../domain/reporting/reportArea";
import type { PermissionGateway } from "../../platform/android/permissionGateway";

export const reportLocationAccuracyMaxM = 150;

export type ReportLocationFailure =
  | "servicesOff"
  | "denied"
  | "blocked"
  | "timeout"
  | "imprecise"
  | "outsideArea"
  | "unknown";

export type ReportAreaResult =
  | { ok: true; areaId: string }
  | { ok: false; reason: ReportLocationFailure };

export async function acquireReportArea(
  gateway: PermissionGateway,
  readFix?: () => Promise<{ lat: number; lng: number; accuracyM: number }>,
): Promise<ReportAreaResult> {
  try {
    if (!(await gateway.servicesOn())) return { ok: false, reason: "servicesOff" };
    let state = await gateway.check();
    if (state === "denied") state = await gateway.request();
    if (state === "permanentlyDenied") return { ok: false, reason: "blocked" };
    if (state !== "granted") return { ok: false, reason: "denied" };
    const reader =
      readFix ??
      (async () => {
        const pos = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        return {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          accuracyM: pos.coords.accuracy ?? 999,
        };
      });
    const withTimeout = await Promise.race([
      reader(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("timeout")), 22000),
      ),
    ]);
    if (withTimeout.accuracyM > reportLocationAccuracyMaxM) {
      return { ok: false, reason: "imprecise" };
    }
    const areaId = reportAreaOf(withTimeout.lat, withTimeout.lng);
    if (!isReportAreaInServedBBox(areaId)) return { ok: false, reason: "outsideArea" };
    return { ok: true, areaId };
  } catch (e: unknown) {
    if (e instanceof Error && e.message === "timeout") return { ok: false, reason: "timeout" };
    return { ok: false, reason: "unknown" };
  }
}

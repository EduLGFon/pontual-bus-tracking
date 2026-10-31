// Share-trip flow decisions. Port of app/lib/ui/features/trip/trip_flow.dart.
// Step order: line chooser (when no line yet) -> consent disclosure ->
// permission pre-prompt -> startSharing -> /trip. Declines and dismissals
// are silent. Only one flow runs at a time (double taps share one flow).
import * as Location from "expo-location";
import { busApi } from "../../../data/api/busApi";
import { consentStore } from "../../../data/prefs/consentStore";
import { ensureForegroundPermission } from "../../../features/trip/permissionGateway";
import { startSharing } from "../../../features/trip/tripService";
import { remoteConfigRepo } from "../../../data/config/remoteConfig";
import { uiStrings } from "../../strings/uiStrings";

export type ShareError = "consent_required" | "no_connection" | "no_gps" | "busy" | "start_failed";

let shareInFlight = false;

export function isShareInFlight(): boolean {
  return shareInFlight;
}

async function currentFix(): Promise<{ lat: number; lng: number; accuracyM: number } | null> {
  try {
    const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High });
    return { lat: pos.coords.latitude, lng: pos.coords.longitude, accuracyM: pos.coords.accuracy ?? 999 };
  } catch {
    return null;
  }
}

/** Refreshes remote config; false when offline (caller shows S13-style message). */
export async function refreshConfigOnline(): Promise<boolean> {
  try {
    return await remoteConfigRepo.refresh(true);
  } catch {
    return false;
  }
}

export async function consentVersion(): Promise<number> {
  try {
    const cfg = await remoteConfigRepo.current();
    return cfg.consent_version;
  } catch {
    return 1;
  }
}

export async function needsConsent(): Promise<boolean> {
  const v = await consentVersion();
  return !(await consentStore.covers(v));
}

export async function acceptConsent(): Promise<void> {
  await consentStore.write(await consentVersion());
}

/**
 * Runs the final leg of the flow after UI gates passed. Returns null on
 * success; otherwise a ShareError for the caller to display.
 */
export async function finishShare(lineId: number): Promise<ShareError | null> {
  if (shareInFlight) return "busy";
  shareInFlight = true;
  try {
    const online = await refreshConfigOnline();
    if (!online) return "no_connection";
    const perm = await ensureForegroundPermission();
    if (!perm) return "no_gps";
    const fix = await currentFix();
    if (!fix) return "no_gps";
    try {
      await startSharing(lineId, {
        lat: fix.lat,
        lng: fix.lng,
        accuracyM: fix.accuracyM,
        batteryPct: 80,
        charging: false,
      });
    } catch {
      return "start_failed";
    }
    return null;
  } finally {
    shareInFlight = false;
  }
}

export function shareErrorMessage(e: ShareError): string {
  switch (e) {
    case "no_connection":
      return uiStrings.shareNoConnection;
    case "no_gps":
      return uiStrings.shareNoGps;
    case "busy":
      return uiStrings.shareBusy;
    default:
      return uiStrings.shareStartFailed;
  }
}

export async function ensureToken(): Promise<boolean> {
  const r = await busApi.getOrCreateToken();
  return r.ok;
}

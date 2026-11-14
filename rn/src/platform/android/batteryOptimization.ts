// Battery exemption for the trip foreground service.
// Samsung and Xiaomi skins pause background GPS even with a location-type
// foreground service. The system exemption dialog keeps sharing alive with
// the screen off. Android only, user-tapped only, never blocks sharing,
// never throws. Needs REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in app.json
// (owner order D61, RN parity D95). See ARCHITECTURE.md 8.6.
import { Platform } from "react-native";
import { Log } from "../../core/logging/log";

// Injectable so tests never touch a native module.
export type RequestExemption = () => Promise<boolean>;

// True when the app already ignores battery optimizations.
// False on web, non-Android, or any failure. Never throws.
export async function isIgnoringBatteryOptimizations(): Promise<boolean> {
  if (Platform.OS !== "android") return false;
  try {
    const battery = await import("expo-battery");
    const enabled = await battery.isBatteryOptimizationEnabledAsync();
    return !enabled;
  } catch {
    return false;
  }
}

// Fires the direct system exemption pop-up. Call only from a user tap while
// a trip shows a lack of data (offline/stalled): an unprompted system dialog
// is the fastest way to lose trust. Returns true when granted. Never throws.
export async function requestIgnoreBatteryOptimizations(): Promise<boolean> {
  if (Platform.OS !== "android") return false;
  try {
    if (await isIgnoringBatteryOptimizations()) return true;
    const pkg = await currentPackageName();
    try {
      const launcher = await import("expo-intent-launcher");
      const action =
        launcher.ActivityAction?.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS ??
        "android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS";
      await launcher.startActivityAsync(action, pkg ? { data: `package:${pkg}` } : {});
    } catch {
      Log.warn("battery exemption dialog failed", { note: "trip continues" });
      return false;
    }
    const granted = await isIgnoringBatteryOptimizations();
    if (!granted) {
      Log.warn("battery exemption denied", { note: "trip continues" });
    }
    return granted;
  } catch {
    Log.warn("battery exemption request failed", { note: "trip continues" });
    return false;
  }
}

async function currentPackageName(): Promise<string | null> {
  try {
    const app = await import("expo-application");
    const id = app.applicationId;
    if (typeof id === "string" && id.length > 0) return id;
  } catch {
    // Fall through to constants.
  }
  try {
    const constants = await import("expo-constants");
    const cfg = constants.default?.expoConfig as
      | { android?: { package?: string } }
      | undefined;
    const pkg = cfg?.android?.package;
    if (typeof pkg === "string" && pkg.length > 0) return pkg;
  } catch {
    // No package name available: the settings list still opens.
  }
  return null;
}

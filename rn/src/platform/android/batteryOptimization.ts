// Battery optimization helpers. Mirrors app/lib/platform/android/battery_optimization.dart.
// Expo has no battery-optimization module installed, so this is a best-effort
// stub that never blocks sharing and never throws. It documents the intent
// (D61: user-tapped system exemption dialog while offline) without adding deps.
import { Platform } from "react-native";
import { Log } from "../../core/logging/log";

export async function isIgnoringBatteryOptimizations(): Promise<boolean> {
  if (Platform.OS !== "android") return false;
  return false;
}

export async function requestIgnoreBatteryOptimizations(): Promise<boolean> {
  if (Platform.OS !== "android") return false;
  try {
    Log.warn("battery exemption unavailable", { note: "trip continues" });
    return false;
  } catch {
    return false;
  }
}

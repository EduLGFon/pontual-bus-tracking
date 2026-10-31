// Notification permission, best effort. Mirrors
// app/lib/platform/android/notification_permission.dart.
// Never blocks sharing, never throws.
import { Platform } from "react-native";
import { Log } from "../../core/logging/log";

export async function ensureNotificationPermission(): Promise<boolean> {
  if (Platform.OS !== "android") return true;
  try {
    Log.warn("notifications check skipped", { note: "trip continues without banner" });
    return false;
  } catch {
    return false;
  }
}

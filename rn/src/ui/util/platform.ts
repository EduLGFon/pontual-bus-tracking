// Platform helpers. Port of app/lib/ui/util/platform.dart.
import { Platform } from "react-native";

export const PlatformInfo = {
  get isWeb() { return Platform.OS === "web"; },
  get isAndroid() { return Platform.OS === "android"; },
  get isIos() { return Platform.OS === "ios"; },
};

export type BrowserFamily = "chromium" | "safari" | "firefox" | "unknown";

export function browserFamilyOf(userAgent: string): BrowserFamily {
  const ua = userAgent.toLowerCase();
  if (ua.includes("firefox")) return "firefox";
  if (ua.includes("safari") && !ua.includes("chrome")) return "safari";
  if (ua.includes("chrome") || ua.includes("edg")) return "chromium";
  return "unknown";
}

export class Haptics {
  constructor(private enabled = true) {}
  selection() { if (!this.enabled || Platform.OS === "web") return; }
  light() { if (!this.enabled || Platform.OS === "web") return; }
  medium() { if (!this.enabled || Platform.OS === "web") return; }
}
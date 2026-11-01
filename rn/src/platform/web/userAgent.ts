// Browser user agent. Mirrors app/lib/platform/web/user_agent.dart.
export function userAgent(): string {
  try {
    if (typeof globalThis.navigator === "undefined") return "";
    return globalThis.navigator.userAgent ?? "";
  } catch {
    return "";
  }
}

export function browserFamily(ua?: string): "chrome" | "safari" | "firefox" | "other" {
  const s = (ua ?? userAgent()).toLowerCase();
  if (s.includes("firefox")) return "firefox";
  if (s.includes("chrome") || s.includes("chromium")) return "chrome";
  if (s.includes("safari")) return "safari";
  return "other";
}

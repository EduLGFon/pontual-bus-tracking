// Sharing health model. Mirrors app/lib/domain/trip/sharing_health.dart.
export type SharingLevel = "ok" | "warn" | "error" | "neutral";
export type SharingOverall = "starting" | "live" | "paused" | "ended";
export type ConnectionValue = "connected" | "reconnecting" | "offline";
export type GpsValue = "good" | "weak" | "noFix" | "off" | "noPermission" | "imprecise" | "searching";
export type DeviceValue = "screenOn" | "lowBattery";
export type SharingIssue =
  | "none"
  | "permission"
  | "locationOff"
  | "offline"
  | "imprecise"
  | "gpsWeak"
  | "gpsNoFix"
  | "lowBattery";

export const weakGpsAccuracyM = 30;
export const staleSendAfterMs = 45 * 1000;
export const lowBatteryPct = 15;
export const startupGraceMs = 3000;

export interface SharingSignals {
  ended: boolean;
  isStarting: boolean;
  offline: boolean;
  servicesOn: boolean;
  permissionGranted: boolean;
  imprecise: boolean;
  nowMs: number;
  accuracyM?: number | null;
  lastSuccessMs?: number | null;
  startedAtMs?: number | null;
  batteryPct?: number | null;
  charging?: boolean;
}

export interface SharingHealth {
  connectionLevel: SharingLevel;
  connectionValue: ConnectionValue;
  gpsLevel: SharingLevel;
  gpsValue: GpsValue;
  deviceLevel: SharingLevel;
  deviceValue: DeviceValue;
  issue: SharingIssue;
  overall: SharingOverall;
  lastSendStale: boolean;
}

function deviceValueOf(s: SharingSignals): DeviceValue {
  const pct = s.batteryPct;
  if (pct != null && pct <= lowBatteryPct && !s.charging) return "lowBattery";
  return "screenOn";
}

function gpsValueOnline(s: SharingSignals): GpsValue {
  const acc = s.accuracyM;
  if (acc == null) {
    return s.lastSuccessMs == null ? "noFix" : "good";
  }
  if (acc > weakGpsAccuracyM) return "weak";
  return "good";
}

export function resolveSharingHealth(s: SharingSignals): SharingHealth {
  if (s.ended) {
    return {
      connectionLevel: "neutral",
      connectionValue: "connected",
      gpsLevel: "neutral",
      gpsValue: "good",
      deviceLevel: "neutral",
      deviceValue: "screenOn",
      issue: "none",
      overall: "ended",
      lastSendStale: false,
    };
  }
  if (!s.permissionGranted) {
    return {
      connectionLevel: "warn",
      connectionValue: s.offline ? "offline" : "connected",
      gpsLevel: "error",
      gpsValue: "noPermission",
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "permission",
      overall: "paused",
      lastSendStale: false,
    };
  }
  if (!s.servicesOn) {
    return {
      connectionLevel: "warn",
      connectionValue: s.offline ? "offline" : "connected",
      gpsLevel: "error",
      gpsValue: "off",
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "locationOff",
      overall: "paused",
      lastSendStale: false,
    };
  }
  if (s.imprecise) {
    return {
      connectionLevel: "warn",
      connectionValue: s.offline ? "offline" : "connected",
      gpsLevel: "error",
      gpsValue: "imprecise",
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "imprecise",
      overall: "paused",
      lastSendStale: false,
    };
  }
  const inGrace = s.startedAtMs != null && s.nowMs - s.startedAtMs! < startupGraceMs;
  if (s.isStarting || (inGrace && s.lastSuccessMs == null)) {
    return {
      connectionLevel: "neutral",
      connectionValue: "reconnecting",
      gpsLevel: "neutral",
      gpsValue: "searching",
      deviceLevel: "neutral",
      deviceValue: deviceValueOf(s),
      issue: "none",
      overall: "starting",
      lastSendStale: false,
    };
  }
  if (s.offline) {
    return {
      connectionLevel: "warn",
      connectionValue: "offline",
      gpsLevel: gpsValueOnline(s) === "good" ? "ok" : "warn",
      gpsValue: gpsValueOnline(s),
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "offline",
      overall: "paused",
      lastSendStale: false,
    };
  }
  const gps = gpsValueOnline(s);
  const stale = s.lastSuccessMs != null && s.nowMs - s.lastSuccessMs! > staleSendAfterMs;
  if (gps === "weak") {
    return {
      connectionLevel: "ok",
      connectionValue: "connected",
      gpsLevel: "warn",
      gpsValue: "weak",
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "gpsWeak",
      overall: "paused",
      lastSendStale: stale,
    };
  }
  if (gps === "noFix") {
    return {
      connectionLevel: "ok",
      connectionValue: "connected",
      gpsLevel: "warn",
      gpsValue: "noFix",
      deviceLevel: deviceValueOf(s) === "lowBattery" ? "warn" : "ok",
      deviceValue: deviceValueOf(s),
      issue: "gpsNoFix",
      overall: "paused",
      lastSendStale: stale,
    };
  }
  if (deviceValueOf(s) === "lowBattery") {
    return {
      connectionLevel: "ok",
      connectionValue: "connected",
      gpsLevel: "ok",
      gpsValue: "good",
      deviceLevel: "warn",
      deviceValue: "lowBattery",
      issue: "lowBattery",
      overall: "paused",
      lastSendStale: stale,
    };
  }
  return {
    connectionLevel: "ok",
    connectionValue: "connected",
    gpsLevel: "ok",
    gpsValue: gps,
    deviceLevel: "ok",
    deviceValue: "screenOn",
    issue: "none",
    overall: "live",
    lastSendStale: stale,
  };
}

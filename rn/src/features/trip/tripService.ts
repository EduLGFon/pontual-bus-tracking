// Trip service: single owner of sharing. Mirrors
// app/lib/features/trip/trip_controller.dart (adapted for expo-location).
// Uses PingClient (latest-wins + backoff), TripSupervisor (health/auto-end),
// server-interval pacing, and one revive-once for spurious `gone`.
import * as Location from "expo-location";
import { busApi } from "../../data/api/busApi";
import { consentStore } from "../../data/prefs/consentStore";
import { useTripStore } from "../../stores";
import type { ServerTripRole } from "../../domain/trip/tripState";
import { PingClient } from "./pingClient";
import { TripSupervisor } from "./tripSupervisor";
import { geolocatorPermissionGateway } from "../../platform/android/permissionGateway";
import {
  acceptFix,
  batteryBucket,
  normalizeHeading,
  normalizeSpeed,
  round5,
} from "./locationService";
import { FIX_ACCURACY_MAX_M } from "../../core/config/env";

let locationSub: Location.LocationSubscription | null = null;
let ping: PingClient | null = null;
let supervisor: TripSupervisor | null = null;
let autoEndTimer: ReturnType<typeof setInterval> | null = null;
let currentToken: string | null = null;
let currentLineId: number | null = null;
let seq = 0;
let lastRole: ServerTripRole = "W";
let nextPingAtMs = 0;
let lastFix: { lat: number; lng: number; accuracyM: number; batteryPct: number; charging: boolean } | null = null;
let revivedOnce = false;
let reviving = false;
let tripGen = 0;

export async function grantConsent(): Promise<void> {
  const rc = (await import("../../data/config/remoteConfig")).remoteConfigRepo;
  const cfg = await rc.current();
  const cv = cfg.consent_version;
  await consentStore.write(cv);
  const reg = await busApi.getOrCreateToken();
  if (reg.ok) {
    const posted = await busApi.postConsents(reg.value, cv);
    if (posted.ok) await consentStore.markPosted(cv);
  }
}

function serverRole(): string {
  if (lastRole === "L") return "L";
  if (lastRole === "F") return "F";
  return "W";
}

function fixBody(fix: {
  lat: number;
  lng: number;
  speedMps: number;
  heading: number | null;
  accuracyM: number;
  batteryPct: number;
  charging: boolean;
}): Record<string, unknown> {
  return {
    seq,
    lat: round5(fix.lat),
    lng: round5(fix.lng),
    spd: normalizeSpeed(fix.speedMps),
    hdg: normalizeHeading(fix.heading, fix.speedMps),
    acc: fix.accuracyM,
    bat: batteryBucket(fix.batteryPct),
    chg: fix.charging,
    role: serverRole(),
  };
}

export async function startSharing(
  lineId: number,
  firstFix: { lat: number; lng: number; accuracyM: number; batteryPct: number; charging: boolean },
) {
  const ts = useTripStore.getState();
  ts.setPhase("starting");
  const reg = await busApi.getOrCreateToken();
  if (!reg.ok) {
    ts.setPhase("idle");
    throw reg.failure;
  }
  currentToken = reg.value;
  const rc = (await import("../../data/config/remoteConfig")).remoteConfigRepo;
  const cfg = await rc.current();
  const cv = cfg.consent_version;
  if (!(await consentStore.covers(cv))) {
    ts.setPhase("idle");
    throw new Error("consent_required");
  }
  if ((await consentStore.readPosted()) !== cv) {
    const posted = await busApi.postConsents(currentToken!, cv);
    if (posted.ok) await consentStore.markPosted(cv);
    else {
      ts.setPhase("idle");
      throw posted.failure;
    }
  }
  const start = await busApi.startTrip(currentToken!, {
    lineId,
    lat: round5(firstFix.lat),
    lng: round5(firstFix.lng),
    accuracyM: firstFix.accuracyM,
    batteryPct: batteryBucket(firstFix.batteryPct),
    charging: firstFix.charging,
  });
  if (!start.ok) {
    ts.setPhase("idle");
    throw start.failure;
  }
  currentLineId = lineId;
  lastRole = start.value.r as ServerTripRole;
  const intervalS = start.value.n;
  seq = 1;
  lastFix = { ...firstFix };
  revivedOnce = false;
  reviving = false;
  tripGen += 1;
  const gen = tripGen;
  nextPingAtMs = Date.now() + intervalS * 1000;
  supervisor = new TripSupervisor(geolocatorPermissionGateway);
  supervisor.begin(Date.now());
  ts.setTrip({ lineId, role: lastRole, intervalS, seq });
  ts.setPhase("sharing");

  ping = new PingClient({
    send: async (body) => {
      const token = currentToken;
      if (!token) return { status: 0 };
      const r = await busApi.pingTrip(token, {
        seq: body["seq"] as number,
        lat: body["lat"] as number,
        lng: body["lng"] as number,
        speedMps: body["spd"] as number,
        heading: (body["hdg"] as number | null) ?? null,
        accuracyM: body["acc"] as number,
        batteryPct: body["bat"] as number,
        charging: body["chg"] as boolean,
        role: body["role"] as string,
      });
      if (!r.ok) {
        const code = (r.failure as { code?: string })?.code;
        if (code === "gone") return { status: 404 };
        if (code === "auth") return { status: 401 };
        return { status: 0 };
      }
      return { status: 200, role: r.value.r, intervalS: r.value.n, end: r.value.e ?? undefined };
    },
    refreshToken: async () => {
      await busApi.getOrCreateToken();
    },
  });

  locationSub = await Location.watchPositionAsync(
    { accuracy: Location.Accuracy.High, timeInterval: 5000, distanceInterval: 10 },
    (loc) => {
      if (!currentToken || currentLineId === null || gen !== tripGen) return;
      const raw = {
        lat: loc.coords.latitude,
        lng: loc.coords.longitude,
        accuracyM: loc.coords.accuracy ?? 999,
        isMocked: loc.mocked ?? false,
        timestampMs: loc.timestamp,
      };
      if (!acceptFix(raw, Date.now())) return;
      const speedMps = Math.max(0, loc.coords.speed ?? 0);
      const fix = {
        lat: raw.lat,
        lng: raw.lng,
        speedMps,
        heading: loc.coords.heading ?? null,
        accuracyM: Math.min(raw.accuracyM, FIX_ACCURACY_MAX_M),
        batteryPct: 50,
        charging: false,
      };
      lastFix = { lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM, batteryPct: 50, charging: false };
      supervisor?.onFix(
        { seq, lat: fix.lat, lng: fix.lng, speedMps: fix.speedMps, heading: fix.heading, accuracyM: fix.accuracyM, batteryPct: 50, charging: false, acceptedAtMs: Date.now() },
        Date.now(),
      );
      if (Date.now() < nextPingAtMs) return;
      const body = { ...fixBody(fix), seq: ++seq };
      ping?.queue(body, (outcome) => {
        if (gen !== tripGen) return;
        void onOutcome(outcome);
      });
    },
  );

  if (autoEndTimer) clearInterval(autoEndTimer);
  autoEndTimer = setInterval(() => {
    void checkAutoEnd();
  }, 30000);
}

async function onOutcome(outcome: { role: string; intervalS: number; end?: string }): Promise<void> {
  const token = currentToken;
  if (!token) return;
  if (outcome.end) {
    if (outcome.end === "gone" && !revivedOnce && !reviving && lastFix && currentLineId !== null) {
      revivedOnce = true;
      reviving = true;
      try {
        const res = await busApi.startTrip(token, {
          lineId: currentLineId,
          lat: lastFix.lat,
          lng: lastFix.lng,
          accuracyM: lastFix.accuracyM,
          batteryPct: lastFix.batteryPct,
          charging: lastFix.charging,
          resume: true,
        });
        reviving = false;
        if (res.ok) {
          tripGen += 1;
          lastRole = res.value.r as ServerTripRole;
          nextPingAtMs = Date.now() + res.value.n * 1000;
          useTripStore.getState().setTrip({ lineId: currentLineId!, role: lastRole, intervalS: res.value.n, seq });
          return;
        }
      } catch {
        reviving = false;
      }
    }
    await stopSharing();
    return;
  }
  nextPingAtMs = Date.now() + outcome.intervalS * 1000;
  lastRole = outcome.role as ServerTripRole;
  supervisor?.onPingSuccess(Date.now());
  useTripStore.getState().setTrip({ lineId: currentLineId!, role: lastRole, intervalS: outcome.intervalS, seq });
}

async function checkAutoEnd(): Promise<void> {
  if (!supervisor || !currentToken || currentLineId === null) return;
  await supervisor.pollEnvironment(Date.now());
  const startedAt = Date.now() - 30 * 1000;
  const round = supervisor.evaluate({
    role: serverRole(),
    failures: ping?.consecutiveFailures ?? 0,
    wasOffline: false,
    startedAtMs: startedAt,
    nowMs: Date.now(),
  });
  if (round.endReason) {
    await stopSharing();
  }
}

export function forcePingNow(): boolean {
  if (!lastFix || !ping || !currentToken) return false;
  const body = { ...fixBody({ ...lastFix, speedMps: 0, heading: null }), seq: ++seq };
  const gen = tripGen;
  nextPingAtMs = 0;
  ping.queue(body, (outcome) => {
    if (gen === tripGen) void onOutcome(outcome);
  });
  return true;
}

export async function stopSharing() {
  const ts = useTripStore.getState();
  ts.setPhase("ending");
  tripGen += 1;
  if (locationSub) {
    locationSub.remove();
    locationSub = null;
  }
  if (autoEndTimer) {
    clearInterval(autoEndTimer);
    autoEndTimer = null;
  }
  ping?.close();
  ping = null;
  supervisor = null;
  if (currentToken) {
    const t = currentToken;
    currentToken = null;
    try {
      await busApi.endTrip(t);
    } catch {}
  }
  currentLineId = null;
  seq = 0;
  ts.reset();
}

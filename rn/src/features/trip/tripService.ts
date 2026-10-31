// Trip service (single owner of sharing). Mirrors app/lib/features/trip/trip_controller.dart (simplified).
import * as Location from "expo-location";
import { busApi } from "../../data/api/busApi";
import { consentStore } from "../../data/prefs/consentStore";
import { useTripStore } from "../../stores";
import type { ServerTripRole } from "../../domain/trip/tripState";

let locationSub: Location.LocationSubscription | null = null;
let currentToken: string | null = null;
let currentLineId: number | null = null;
let seq = 0;
let lastRole: ServerTripRole = "W";

export async function startSharing(lineId: number, firstFix: { lat: number; lng: number; accuracyM: number; batteryPct: number; charging: boolean }) {
  const ts = useTripStore.getState();
  ts.setPhase("starting");
  const reg = await busApi.getOrCreateToken();
  if (!reg.ok) {
    ts.setPhase("idle");
    throw reg.failure;
  }
  currentToken = reg.value;
  // consent
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
    lat: firstFix.lat,
    lng: firstFix.lng,
    accuracyM: firstFix.accuracyM,
    batteryPct: firstFix.batteryPct,
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
  ts.setTrip({ lineId, role: lastRole, intervalS, seq });
  ts.setPhase("sharing");
  // location watch
  locationSub = await Location.watchPositionAsync(
    { accuracy: Location.Accuracy.High, timeInterval: 5000, distanceInterval: 10 },
    async (loc) => {
      if (!currentToken || !currentLineId) return;
      const fix = loc.coords;
      const spd = fix.speed ?? 0;
      const res = await busApi.pingTrip(currentToken!, {
        seq: ++seq,
        lat: fix.latitude,
        lng: fix.longitude,
        speedMps: Math.max(0, spd),
        heading: fix.heading ?? null,
        accuracyM: fix.accuracy ?? 0,
        batteryPct: 50,
        charging: false,
        role: lastRole,
      });
      if (!res.ok) {
        if ((res.failure as any)?.code === "gone") {
          await stopSharing();
        }
        return;
      }
      lastRole = res.value.r as ServerTripRole;
      const intervalS = res.value.n;
      if (res.value.e) {
        await stopSharing();
        return;
      }
      useTripStore.getState().setTrip({
        lineId: currentLineId!,
        role: lastRole,
        intervalS,
        seq,
      });
    },
  );
  // Note: watchPositionAsync already drives pings; intervalS from server
  // is advisory. We keep it in state for UI.
}

export async function stopSharing() {
  const ts = useTripStore.getState();
  ts.setPhase("ending");
  if (locationSub) {
    locationSub.remove();
    locationSub = null;
  }
  if (currentToken) {
    await busApi.endTrip(currentToken).catch(() => {});
  }
  currentToken = null;
  currentLineId = null;
  seq = 0;
  ts.reset();
}

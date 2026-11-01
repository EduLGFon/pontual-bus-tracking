// Trip adapter. Port of app/lib/ui/adapters/trip_adapter.dart.
import type { TripVM, TripPhase } from "../models/trip_vm";

export function tripVmOf(controller: any): TripVM {
  const state = controller?.state;
  const active = state?.type === "active";
  let phase: TripPhase = "idle";
  if (state?.type === "idle") phase = "idle";
  else if (controller?.isPaused) phase = "paused";
  else if (controller?.isOffline) phase = "reconnecting";
  else if (active) phase = "active";
  else phase = "starting";
  return {
    phase,
    lineKey: controller?.lineId != null ? String(controller.lineId) : null,
    lineLabel: controller?.lineLabel ?? "",
    elapsedS: 0,
    gpsOff: !!controller?.isPaused,
    webHidden: !!controller?.isWebHidden,
    role: "waiting",
  };
}

export function formatElapsed(elapsedS: number): string {
  const hh = String(Math.floor(elapsedS / 3600)).padStart(2, "0");
  const mm = String(Math.floor((elapsedS / 60) % 60)).padStart(2, "0");
  const ss = String(elapsedS % 60).padStart(2, "0");
  return `${hh}:${mm}:${ss}`;
}
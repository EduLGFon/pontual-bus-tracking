// Line dock. Port of app/lib/ui/features/line/line_dock.dart.
// Contextual: "Estou neste ônibus" on a shareable (pilot) line, hidden
// otherwise. Shows sharing state when a trip is active.
import React from "react";
import { useRouter } from "expo-router";
import { TripDock } from "../../design/components/trip_dock";
import { useTripStore } from "../../../stores";
import { tripVmOf } from "../../adapters/trip_adapter";
import { uiStrings } from "../../strings/uiStrings";

export function LineDock({ lineKey, shareable }: { lineKey: string; shareable: boolean }) {
  const router = useRouter();
  const phase = useTripStore((s) => s.phase);
  const trip = useTripStore((s) => s.trip);
  if (!shareable && phase === "idle") return null;
  const vm = tripVmOf({ state: { type: phase === "idle" ? "idle" : "active" }, lineId: trip?.lineId, lineLabel: "" });
  return (
    <TripDock
      trip={vm}
      idleLabel={uiStrings.dockIdleOnLine}
      onPress={() => router.push({ pathname: "/trip", params: { line: lineKey } })}
    />
  );
}

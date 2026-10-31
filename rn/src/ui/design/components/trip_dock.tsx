// TripDock. Port of app/lib/ui/design/components/trip_dock.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { TripVM } from "../../models/trip_vm";
import { tripInProgress } from "../../models/trip_vm";
import { uiStrings } from "../../strings/uiStrings";
import { LiveDot } from "./live_dot";
import { Pressable } from "./pressable";

function messageOf(trip: TripVM, idleLabel: string): string {
  switch (trip.phase) {
    case "idle":
      return idleLabel;
    case "starting":
      return uiStrings.dockStarting;
    case "active":
      return trip.lineLabel != null && trip.lineLabel !== "" ? `${uiStrings.dockSharing} · ${trip.lineLabel}` : uiStrings.dockSharing;
    case "reconnecting":
      return uiStrings.dockReconnecting;
    case "paused":
      return uiStrings.dockGpsOff;
  }
}

export function TripDock({ trip, idleLabel, onPress }: { trip: TripVM; idleLabel: string; onPress?: () => void }) {
  const t = useTheme();
  const active = tripInProgress(trip);
  const problem = trip.phase === "reconnecting" || trip.phase === "paused";
  const accent = problem ? t.colors.warning : t.colors.live;
  const fill = active ? t.colors.surfaceRaised : t.colors.primary;
  const labelColor = active ? t.colors.ink : t.colors.onPrimary;
  const label = messageOf(trip, idleLabel);
  const disabled = trip.phase === "starting";
  return (
    <View style={styles.align}>
      <Pressable
        onPress={disabled ? undefined : onPress}
        accessibilityLabel={trip.phase === "idle" ? idleLabel : `${label}. ${uiStrings.tripTitle}`}
        borderRadius={999}
        minSize={56}>
        <View
          style={[
            styles.pill,
            { backgroundColor: fill, borderColor: active ? accent : t.colors.bg },
          ]}>
          {active ? <LiveDot certainty="live" size={8} /> : null}
          <Text style={[t.text.label, { color: labelColor }]} numberOfLines={1}>
            {label}
          </Text>
          <Text style={[styles.chev, { color: labelColor }]}>∨</Text>
        </View>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  align: { alignItems: "center", paddingHorizontal: 16 },
  pill: { height: 56, borderRadius: 999, borderWidth: 1, paddingHorizontal: 16, flexDirection: "row", alignItems: "center", gap: 8, maxWidth: 420 },
  chev: { fontSize: 16 },
});

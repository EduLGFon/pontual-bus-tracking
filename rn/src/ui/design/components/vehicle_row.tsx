// VehicleRow. Port of app/lib/ui/design/components/vehicle_row.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { VehicleVM } from "../../models/vehicle_vm";
import { aboard, uiStrings } from "../../strings/uiStrings";
import { LiveDot } from "./live_dot";
import { SurfaceCard } from "./surface_card";
import { GhostLink } from "./ghost_link";

function ageText(ageSeconds: number): string {
  if (ageSeconds < 60) return `há ${ageSeconds} s`;
  return `há ${Math.ceil(ageSeconds / 60)} min`;
}

export function VehicleRow({
  vehicle,
  onPress,
  onFollow,
  selected = false,
}: {
  vehicle: VehicleVM;
  onPress?: () => void;
  onFollow?: () => void;
  selected?: boolean;
}) {
  const t = useTheme();
  const ordinal = vehicle.ordinal ?? 1;
  const label = `Ônibus ${ordinal}`;
  const speed = vehicle.speedKmh == null ? "" : `${Math.round(vehicle.speedKmh)} km/h`;
  const bits = [ageText(vehicle.ageSeconds), speed, aboard(vehicle.members ?? 0)].filter(Boolean).join(" · ");
  return (
    <SurfaceCard onPress={onPress} selected={selected} accessibilityLabel={`${label}, ${bits}`}>
      <View style={styles.row}>
        <LiveDot certainty="live" />
        <View style={styles.main}>
          <Text style={t.text.headline}>{label}</Text>
          <Text style={t.text.caption}>{bits}</Text>
        </View>
        {onFollow != null ? <GhostLink label={uiStrings.follow} onPress={onFollow} /> : null}
      </View>
    </SurfaceCard>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", gap: 8, minHeight: 48 },
  main: { flex: 1, gap: 4 },
});

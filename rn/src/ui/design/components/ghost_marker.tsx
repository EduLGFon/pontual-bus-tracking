// GhostMarker. Port of app/lib/ui/design/components/ghost_marker.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { uiStrings } from "../../strings/uiStrings";
import { VehicleMarker } from "./vehicle_marker";

export function GhostMarker({
  lineKey,
  ordinal,
  onPress,
}: {
  lineKey: string;
  ordinal?: number;
  onPress?: () => void;
}) {
  const t = useTheme();
  return (
    <View accessibilityLabel={uiStrings.ghostPredictionLabel} style={styles.root}>
      <View style={[styles.chip, { backgroundColor: t.colors.predicted }]}>
        <Text style={[styles.chipText, { color: "#FFFFFF" }]}>~</Text>
      </View>
      <VehicleMarker lineKey={lineKey} ordinal={ordinal} dashed onPress={onPress} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: "center", minWidth: 44, minHeight: 44 },
  chip: { borderRadius: 999, paddingHorizontal: 8, paddingVertical: 2, marginBottom: 2 },
  chipText: { fontSize: 12, fontWeight: "700" },
});

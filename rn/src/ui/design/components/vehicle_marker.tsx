// VehicleMarker. Port of app/lib/ui/design/components/vehicle_marker.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { lineColorOf, lineBadgeTextOf } from "../tokens/line_colors";
import { aboard } from "../../strings/uiStrings";
import { Pressable } from "./pressable";

export function VehicleMarker({
  lineKey,
  ordinal = 1,
  ageSeconds = 0,
  members = 0,
  selected = false,
  dashed = false,
  onPress,
}: {
  lineKey: string;
  ordinal?: number;
  ageSeconds?: number;
  members?: number;
  selected?: boolean;
  dashed?: boolean;
  onPress?: () => void;
}) {
  const t = useTheme();
  const fill = lineColorOf(lineKey, t.resolved);
  const glyph = lineBadgeTextOf(fill);
  const age = ageSeconds < 60 ? `${ageSeconds} s` : `${Math.ceil(ageSeconds / 60)} min`;
  const label = `Ônibus ${ordinal}, há ${age}, ${aboard(members)}`;
  return (
    <Pressable onPress={onPress} accessibilityLabel={label} borderRadius={999} minSize={44}>
      <View
        style={[
          styles.body,
          {
            backgroundColor: dashed ? "transparent" : fill,
            borderColor: fill,
            borderStyle: dashed ? "dashed" : "solid",
            borderWidth: selected ? 3 : 2,
            opacity: dashed ? 0.85 : 1,
          },
        ]}>
        <Text style={[styles.glyph, { color: dashed ? fill : glyph }]}>{ordinal}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  body: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center" },
  glyph: { fontSize: 16, fontWeight: "800" },
});

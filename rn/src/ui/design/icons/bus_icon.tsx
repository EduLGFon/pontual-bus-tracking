// Bus icon, front view. Port of app/lib/ui/design/icons/bus_icon.dart.
// Drawn with Views so no icon font or svg dependency is needed.
import React from "react";
import { View, StyleSheet } from "react-native";

export function BusIcon({
  size = 24,
  color,
  filled = true,
}: {
  size?: number;
  color: string;
  filled?: boolean;
}) {
  const s = size / 24;
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Ônibus"
      style={[styles.body, { width: size, height: size, borderColor: color }]}>
      <View style={[styles.bus, { borderColor: color, backgroundColor: filled ? color : "transparent", borderRadius: 4 * s }]}>
        <View style={[styles.window, { borderColor: filled ? "#FFFFFF" : color }]} />
        <View style={[styles.line, { backgroundColor: filled ? "#FFFFFF" : color }]} />
      </View>
      <View style={styles.wheels}>
        <View style={[styles.wheel, { backgroundColor: color }]} />
        <View style={[styles.wheel, { backgroundColor: color }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { alignItems: "center", justifyContent: "center" },
  bus: { width: "75%", height: "62%", borderWidth: 1.75, alignItems: "center", justifyContent: "center" },
  window: { width: "60%", height: "38%", borderWidth: 1.5 },
  line: { width: "66%", height: 1.75, marginTop: 3 },
  wheels: { flexDirection: "row", justifyContent: "space-between", width: "62%", marginTop: 2 },
  wheel: { width: 5, height: 5, borderRadius: 999 },
});

// Live waves icon. Port of app/lib/ui/design/icons/live_waves_icon.dart.
import React from "react";
import { View, StyleSheet } from "react-native";

export function LiveWavesIcon({ size = 16, color }: { size?: number; color: string }) {
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Ao vivo"
      style={[styles.root, { width: size, height: size }]}>
      <View style={[styles.dot, { backgroundColor: color, width: size * 0.25, height: size * 0.25 }]} />
      <View style={[styles.arc, { borderColor: color, width: size * 0.62, height: size * 0.62 }]} />
      <View style={[styles.arc2, { borderColor: color, width: size * 0.95, height: size * 0.95 }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: "center", justifyContent: "center" },
  dot: { borderRadius: 999, position: "absolute", left: "8%" },
  arc: { borderRadius: 999, borderWidth: 2, borderLeftColor: "transparent", position: "absolute" },
  arc2: { borderRadius: 999, borderWidth: 2, borderLeftColor: "transparent", position: "absolute", opacity: 0.6 },
});

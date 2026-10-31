// Spark icon for predicted certainty. Port of app/lib/ui/design/icons/spark_icon.dart.
import React from "react";
import { View, StyleSheet } from "react-native";

export function SparkIcon({ size = 16, color }: { size?: number; color: string }) {
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Previsão"
      style={[styles.root, { width: size, height: size }]}>
      <View style={[styles.diamond, { borderColor: color, width: size * 0.5, height: size * 0.5 }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: "center", justifyContent: "center" },
  diamond: { borderWidth: 1.75, transform: [{ rotate: "45deg" }] },
});

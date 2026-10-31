// ConfidenceMeter. Port of app/lib/ui/design/components/confidence_meter.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { confidenceLabel } from "../../strings/uiStrings";

export function ConfidenceMeter({ level }: { level: number }) {
  const t = useTheme();
  const clamped = Math.max(0, Math.min(2, level));
  const filled = clamped + 1;
  return (
    <View accessibilityRole="image" accessibilityLabel={confidenceLabel(clamped)} style={styles.row}>
      {[0, 1, 2].map((i) => (
        <View
          key={i}
          style={[styles.bar, { height: 8 + i * 5, marginLeft: i === 0 ? 0 : 3, backgroundColor: i < filled ? t.colors.primary : t.colors.line }]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-end", minHeight: 24 },
  bar: { width: 6, borderRadius: 2 },
});

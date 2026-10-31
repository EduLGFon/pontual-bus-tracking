// Sparkline. Port of app/lib/ui/design/components/sparkline.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { uiStrings } from "../../strings/uiStrings";

export function Sparkline({ bars, height = 32 }: { bars: number[]; height?: number }) {
  const t = useTheme();
  if (bars.length === 0) return null;
  return (
    <View accessibilityLabel={uiStrings.delayHistoryLabel} style={[styles.row, { height }]}>
      {bars.map((v, i) => {
        const clamped = Math.max(0, Math.min(1, v));
        const h = Math.max(2, height * clamped);
        return <View key={i} style={[styles.bar, { height: h, backgroundColor: t.colors.primary }]} />;
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "flex-end", gap: 3, minHeight: 32 },
  bar: { width: 8, borderRadius: 2 },
});

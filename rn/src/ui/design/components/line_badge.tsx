// LineBadge. Port of app/lib/ui/design/components/line_badge.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { lineColorOf, lineBadgeTextOf } from "../tokens/line_colors";
import { BusIcon } from "../icons/bus_icon";

export type BadgeSize = "s" | "m" | "l";

const heights: Record<BadgeSize, number> = { s: 24, m: 28, l: 40 };
const fontSizes: Record<BadgeSize, number> = { s: 11, m: 13, l: 18 };

export function LineBadge({
  lineKey,
  text,
  size = "m",
  color,
  dimmed = false,
}: {
  lineKey: string;
  text: string;
  size?: BadgeSize;
  color?: string | null;
  dimmed?: boolean;
}) {
  const t = useTheme();
  const resolved = lineColorOf(lineKey, t.resolved, color ?? null);
  const onFill = lineBadgeTextOf(resolved);
  const h = heights[size];
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel={text || "Linha"}
      style={[styles.badge, { minHeight: h, minWidth: (h * 10) / 7, backgroundColor: resolved, opacity: dimmed ? 0.55 : 1 }]}>
      {text === "" ? (
        <BusIcon size={h * 0.6} color={onFill} />
      ) : (
        <Text style={[styles.text, { fontSize: fontSizes[size], color: onFill }]} numberOfLines={1}>
          {text}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { paddingHorizontal: 8, borderRadius: 999, alignItems: "center", justifyContent: "center" },
  text: { fontWeight: "700" },
});

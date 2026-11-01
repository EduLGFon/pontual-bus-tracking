// DashedOutline. Port of app/lib/ui/design/components/dashed_outline.dart.
import React from "react";
import { View, StyleSheet, type ViewStyle } from "react-native";
import { useTheme } from "../theme/context";

export function DashedOutline({
  radius = 12,
  color,
  style,
  children,
}: {
  radius?: number;
  color?: string;
  style?: ViewStyle;
  children?: React.ReactNode;
}) {
  const t = useTheme();
  return (
    <View style={[styles.box, { borderRadius: radius, borderColor: color ?? t.colors.predicted }, style]}>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  box: { borderWidth: 1, borderStyle: "dashed" },
});

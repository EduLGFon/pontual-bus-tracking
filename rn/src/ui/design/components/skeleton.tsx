// Skeleton. Port of app/lib/ui/design/components/skeleton.dart.
import React from "react";
import { View, StyleSheet, type ViewStyle } from "react-native";
import { useTheme } from "../theme/context";

export function Skeleton({
  width,
  height = 16,
  radius = 8,
  style,
}: {
  width?: number;
  height?: number;
  radius?: number;
  style?: ViewStyle;
}) {
  const t = useTheme();
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Carregando"
      style={[styles.block, { width, height, borderRadius: radius, backgroundColor: t.colors.surfaceSunken }, style]}
    />
  );
}

export function PulsingSkeleton(props: { width?: number; height?: number; radius?: number }) {
  return <Skeleton {...props} />;
}

const styles = StyleSheet.create({ block: { minHeight: 16 } });

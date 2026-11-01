import React from "react";
import { Pressable, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function Chip({ label, selected, onPress }: { label: string; selected?: boolean; onPress?: () => void }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} style={[styles.chip, { backgroundColor: selected ? t.colors.primary : t.colors.surfaceSunken, minHeight: 36 }]}>
      <Text style={{ ...t.text.label, color: selected ? t.colors.onPrimary : t.colors.ink }}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({ chip: { paddingHorizontal: 12, borderRadius: 999, alignItems: "center", justifyContent: "center" } });
import React from "react";
import { Pressable, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function PrimaryButton({ label, onPress }: { label: string; onPress?: () => void }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} style={[styles.btn, { backgroundColor: t.colors.primary, minHeight: 48 }]}>
      <Text style={{ ...t.text.label, color: t.colors.onPrimary }}>{label}</Text>
    </Pressable>
  );
}

export function SecondaryButton({ label, onPress }: { label: string; onPress?: () => void }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} style={[styles.btn, { backgroundColor: t.colors.surfaceSunken, minHeight: 48 }]}>
      <Text style={t.text.label}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({ btn: { paddingHorizontal: 16, borderRadius: 12, alignItems: "center", justifyContent: "center" } });
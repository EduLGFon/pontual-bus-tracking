import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { CertaintyTone } from "../tokens/colors";

export function CertaintyBadge({ tone, label }: { tone: CertaintyTone; label?: string }) {
  const t = useTheme();
  const fill = t.colors.graphicOf(tone);
  const text = t.colors.textOf(tone);
  return (
    <View style={[styles.badge, { backgroundColor: fill }]}>
      <Text style={[styles.text, { color: text }]}>{label ?? tone}</Text>
    </View>
  );
}

const styles = StyleSheet.create({ badge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 999, minHeight: 24 }, text: { fontSize: 12 } });
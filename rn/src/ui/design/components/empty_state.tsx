// EmptyState. Port of app/lib/ui/design/components/empty_state.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export type EmptyArt = "bus" | "search" | "pin" | "cloud" | "wrench";

const artGlyphs: Record<EmptyArt, string> = {
  bus: "◫",
  search: "○",
  pin: "◎",
  cloud: "☁",
  wrench: "✦",
};

export function EmptyState({
  title,
  message,
  art = "bus",
  actionLabel,
  onAction,
  secondaryLabel,
  onSecondary,
}: {
  title: string;
  message: string;
  art?: EmptyArt;
  actionLabel?: string;
  onAction?: () => void;
  secondaryLabel?: string;
  onSecondary?: () => void;
}) {
  const t = useTheme();
  return (
    <View accessibilityLabel={`${title}. ${message}`} style={styles.root}>
      <View style={[styles.art, { borderColor: t.colors.line }]}>
        <Text style={[styles.glyph, { color: t.colors.inkMuted }]}>{artGlyphs[art]}</Text>
      </View>
      <Text style={[t.text.title, styles.center]}>{title}</Text>
      <Text style={[t.text.body, styles.center]}>{message}</Text>
      {actionLabel != null && onAction != null ? (
        <Pressable onPress={onAction} accessibilityLabel={actionLabel} borderRadius={999}>
          <View style={[styles.primary, { backgroundColor: t.colors.primary }]}>
            <Text style={[t.text.label, { color: t.colors.onPrimary }]}>{actionLabel}</Text>
          </View>
        </Pressable>
      ) : null}
      {secondaryLabel != null && onSecondary != null ? (
        <Pressable onPress={onSecondary} accessibilityLabel={secondaryLabel} borderRadius={999}>
          <Text style={[t.text.label, { color: t.colors.primary, padding: 8 }]}>{secondaryLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: "center", padding: 24, gap: 8 },
  art: { width: 96, height: 96, borderWidth: 1, borderRadius: 24, alignItems: "center", justifyContent: "center" },
  glyph: { fontSize: 40 },
  center: { textAlign: "center" },
  primary: { height: 56, paddingHorizontal: 24, borderRadius: 999, alignItems: "center", justifyContent: "center" },
});

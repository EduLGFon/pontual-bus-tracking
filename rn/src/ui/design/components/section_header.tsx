// SectionHeader. Port of app/lib/ui/design/components/section_header.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { GhostLink } from "./ghost_link";

export function SectionHeader({
  title,
  subtitle,
  actionLabel,
  onAction,
  topSpacing = 24,
}: {
  title: string;
  subtitle?: string;
  actionLabel?: string;
  onAction?: () => void;
  topSpacing?: number;
}) {
  const t = useTheme();
  return (
    <View style={[styles.row, { paddingTop: topSpacing }]}>
      <View style={styles.main}>
        <Text style={t.text.title} accessibilityRole="header">
          {title}
        </Text>
        {subtitle != null ? <Text style={t.text.caption}>{subtitle}</Text> : null}
      </View>
      {actionLabel != null && onAction != null ? <GhostLink label={actionLabel} onPress={onAction} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", paddingBottom: 12, minHeight: 48 },
  main: { flex: 1, gap: 4 },
});

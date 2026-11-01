// Settings section. Port of app/lib/ui/features/settings/settings_section.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";

export function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
  const t = useTheme();
  return (
    <View style={styles.section}>
      <Text style={[t.text.headline, styles.title]} accessibilityRole="header">
        {title}
      </Text>
      <View style={[styles.card, { backgroundColor: t.colors.surface, borderColor: t.colors.line }]}>
        {children}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  section: { marginTop: 24 },
  title: { marginBottom: 8, paddingHorizontal: 16 },
  card: { borderWidth: 1, borderRadius: 16, overflow: "hidden" },
});

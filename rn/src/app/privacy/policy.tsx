// Bundled privacy policy (offline). Full text lives in docs/privacy/.
import React from "react";
import { ScrollView, Text, StyleSheet } from "react-native";
import { useTheme } from "../../ui/design/theme/context";
import { uiStrings } from "../../ui/strings/uiStrings";
import { bundledPolicy } from "../../features/settings/privacyTexts";

export default function PolicyRoute() {
  const t = useTheme();
  return (
    <ScrollView style={[styles.root, { backgroundColor: t.colors.bg }]} contentContainerStyle={styles.content}>
      <Text style={t.text.display} accessibilityRole="header">
        {uiStrings.privacyPolicy}
      </Text>
      <Text style={[t.text.body, styles.body]}>{bundledPolicy}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  body: { marginTop: 12 },
});

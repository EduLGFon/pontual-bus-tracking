// Bundled terms of use (offline). Full text lives in docs/privacy/.
import React from "react";
import { ScrollView, Text, StyleSheet } from "react-native";
import { useTheme } from "../../ui/design/theme/context";
import { bundledTerms } from "../../features/settings/privacyTexts";

export default function TermsRoute() {
  const t = useTheme();
  return (
    <ScrollView style={[styles.root, { backgroundColor: t.colors.bg }]} contentContainerStyle={styles.content}>
      <Text style={t.text.display} accessibilityRole="header">
        Termos de uso
      </Text>
      <Text style={[t.text.body, styles.body]}>{bundledTerms}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  body: { marginTop: 12 },
});

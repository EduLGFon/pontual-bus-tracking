// PontualSheet. Port of app/lib/ui/design/components/pontual_sheet.dart.
import React from "react";
import { View, Text, ScrollView, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function PontualSheet({
  title,
  scrollable = false,
  children,
}: {
  title?: string;
  scrollable?: boolean;
  children: React.ReactNode;
}) {
  const t = useTheme();
  const body = scrollable ? <ScrollView>{children}</ScrollView> : <View>{children}</View>;
  return (
    <View style={[styles.sheet, { backgroundColor: t.colors.surface, borderTopColor: t.colors.line }]}>
      <View style={styles.grabRow}>
        <View style={[styles.grab, { backgroundColor: t.colors.line }]} />
      </View>
      {title != null ? (
        <Text style={[t.text.title, styles.title]} accessibilityRole="header">
          {title}
        </Text>
      ) : null}
      <View style={styles.body}>{body}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: { borderTopLeftRadius: 24, borderTopRightRadius: 24, borderTopWidth: 1, paddingHorizontal: 24, paddingBottom: 32 },
  grabRow: { alignItems: "center", paddingTop: 8 },
  grab: { width: 36, height: 4, borderRadius: 999 },
  title: { marginTop: 12 },
  body: { marginTop: 8 },
});

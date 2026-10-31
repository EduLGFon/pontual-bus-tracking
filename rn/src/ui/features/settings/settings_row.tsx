// Settings row. Port of app/lib/ui/features/settings/settings_row.dart.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { Pressable } from "../../design/components/pressable";

export function SettingsRow({
  title,
  subtitle,
  value,
  onPress,
}: {
  title: string;
  subtitle?: string;
  value?: string;
  onPress?: () => void;
}) {
  const t = useTheme();
  return (
    <Pressable
      onPress={onPress}
      accessibilityLabel={value ? `${title}, ${value}` : title}
      borderRadius={0}
      minSize={56}>
      <View style={[styles.row, { borderBottomColor: t.colors.line }]}>
        <View style={styles.main}>
          <Text style={t.text.bodyStrong}>{title}</Text>
          {subtitle ? (
            <Text style={[t.text.caption, { color: t.colors.inkMuted }]} numberOfLines={2}>
              {subtitle}
            </Text>
          ) : null}
        </View>
        {value ? <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{value}</Text> : null}
        {onPress ? (
          <Text style={[styles.chev, { color: t.colors.inkMuted }]} aria-hidden={true}>
            {"›"}
          </Text>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", minHeight: 56, paddingHorizontal: 16, gap: 12, borderBottomWidth: 1 },
  main: { flex: 1, gap: 2, paddingVertical: 8 },
  chev: { fontSize: 22 },
});

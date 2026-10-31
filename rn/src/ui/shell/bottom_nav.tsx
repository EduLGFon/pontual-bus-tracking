// Bottom nav. Port of app/lib/ui/shell/bottom_nav.dart.
import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { useTheme } from "../design/theme/context";

export interface BottomNavProps {
  items: { key: string; label: string }[];
  active: string;
  onSelect: (key: string) => void;
}

export function BottomNav({ items, active, onSelect }: BottomNavProps) {
  const t = useTheme();
  return (
    <View style={[styles.bar, { backgroundColor: t.colors.surface, borderTopColor: t.colors.line }]}>
      {items.map((it) => (
        <Pressable
          key={it.key}
          onPress={() => onSelect(it.key)}
          accessibilityRole="tab"
          accessibilityLabel={it.label}
          style={styles.item}
        >
          <Text style={[t.text.label, { color: active === it.key ? t.colors.primary : t.colors.inkMuted }]}>
            {it.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: { flexDirection: "row", height: 64, borderTopWidth: 1, alignItems: "center", justifyContent: "space-around" },
  item: { minWidth: 48, minHeight: 48, alignItems: "center", justifyContent: "center" },
});
// Segmented control. Port of app/lib/ui/design/components/segmented.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export interface Segment {
  value: string;
  label: string;
}

export function Segmented({
  segments,
  value,
  onChange,
}: {
  segments: Segment[];
  value: string;
  onChange: (v: string) => void;
}) {
  const t = useTheme();
  return (
    <View
      accessibilityRole="radiogroup"
      style={[styles.track, { backgroundColor: t.colors.surfaceSunken }]}>
      {segments.map((s) => {
        const selected = s.value === value;
        return (
          <View key={s.value} style={styles.cell}>
            <Pressable
              onPress={() => {
                if (s.value !== value) onChange(s.value);
              }}
              accessibilityLabel={s.label}
              borderRadius={999}
              minSize={48}>
              <View
                accessibilityRole="radio"
                accessibilityState={{ selected }}
                style={[styles.thumb, selected ? { backgroundColor: t.colors.primary } : null]}>
                <Text
                  style={[t.text.label, { color: selected ? t.colors.onPrimary : t.colors.inkMuted }]}
                  numberOfLines={1}>
                  {s.label}
                </Text>
              </View>
            </Pressable>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  track: { height: 56, borderRadius: 999, padding: 4, flexDirection: "row", alignItems: "center" },
  cell: { flex: 1 },
  thumb: { height: 48, borderRadius: 999, alignItems: "center", justifyContent: "center", paddingHorizontal: 8 },
});

// TimeRail. Port of app/lib/ui/design/components/time_rail.dart.
import React from "react";
import { View, Text, ScrollView, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export interface TimeRailHour {
  hour: string;
  minutes: string[];
}

function minutesOf(hour: string, minute: string): number {
  return parseInt(hour, 10) * 60 + parseInt(minute, 10);
}

export function TimeRail({
  hours,
  nextHour,
  nextMinute,
  nowMinutes,
  onSelect,
}: {
  hours: TimeRailHour[];
  nextHour?: string;
  nextMinute?: string;
  nowMinutes?: number;
  onSelect?: (value: string) => void;
}) {
  const t = useTheme();
  return (
    <ScrollView accessibilityLabel="Horários" style={styles.list}>
      {hours.map((row) => {
        const isNext = row.hour === nextHour;
        return (
          <View key={row.hour} style={styles.row}>
            <Text style={[t.text.headline, { color: isNext ? t.colors.ink : t.colors.inkSubtle, width: 32 }]}>
              {row.hour}
            </Text>
            <View style={styles.chips}>
              {row.minutes.map((m) => {
                const value = `${row.hour}:${m}`;
                const past = nowMinutes != null && minutesOf(row.hour, m) < nowMinutes;
                const highlight = isNext && m === nextMinute;
                return (
                  <Pressable key={m} onPress={() => onSelect?.(value)} accessibilityLabel={value} borderRadius={8} minSize={48}>
                    <View
                      style={[
                        styles.chip,
                        highlight ? { backgroundColor: t.colors.primary } : null,
                      ]}>
                      <Text
                        style={[
                          t.text.label,
                          { color: highlight ? t.colors.onPrimary : t.colors.ink, opacity: past && !highlight ? 0.45 : 1 },
                        ]}>
                        {m}
                      </Text>
                    </View>
                  </Pressable>
                );
              })}
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  list: { flexGrow: 0 },
  row: { flexDirection: "row", alignItems: "center", minHeight: 56, gap: 12 },
  chips: { flex: 1, flexDirection: "row", flexWrap: "wrap", gap: 8 },
  chip: { minWidth: 48, minHeight: 48, alignItems: "center", justifyContent: "center", paddingHorizontal: 8, borderRadius: 8 },
});

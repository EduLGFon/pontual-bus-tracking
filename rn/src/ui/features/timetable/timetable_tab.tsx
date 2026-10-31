// Timetable tab. Port of app/lib/ui/features/timetable/timetable_tab.dart.
// No network: renders bundled schedules with day-type + origin pickers,
// next departure highlight, hour groups, dimmed past times.
import React, { useMemo, useState } from "react";
import { ScrollView, Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { Chip } from "../../design/components/chip";
import { EmptyState } from "../../design/components/empty_state";
import { Segmented } from "../../design/components/segmented";
import type { StaticLine } from "../../../data/static/staticData";
import { uiStrings } from "../../strings/uiStrings";
import { dayTypeOf, groupByHour, nextTime, nowHHMM, originsOf, timesOf, type DayType } from "./timetable_data";

export function TimetableTab({ line, now }: { line: StaticLine; now?: Date }) {
  const t = useTheme();
  const current = now ?? new Date();
  const [day, setDay] = useState<DayType>(dayTypeOf(current));
  const origins = useMemo(() => originsOf(line, day), [line, day]);
  const [origin, setOrigin] = useState<string | null>(null);
  const effectiveOrigin = origin != null && origins.includes(origin) ? origin : (origins[0] ?? null);
  const times = useMemo(() => timesOf(line, day, effectiveOrigin), [line, day, effectiveOrigin]);
  const clock = nowHHMM(current);
  const upcoming = nextTime(times, clock);
  const groups = useMemo(() => groupByHour(times), [times]);

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.content}>
      <Segmented
        segments={[
          { value: "weekday", label: uiStrings.dayWeekday },
          { value: "saturday", label: uiStrings.daySaturday },
          { value: "sunday", label: uiStrings.daySunday },
        ]}
        value={day}
        onChange={(v) => setDay(v as DayType)}
      />
      {origins.length > 1 ? (
        <View style={styles.origins}>
          {origins.map((o) => (
            <Chip
              key={o}
              label={`${uiStrings.originLabel} ${o}`}
              selected={o === effectiveOrigin}
              onPress={() => setOrigin(o)}
            />
          ))}
        </View>
      ) : null}
      {times.length === 0 ? (
        <EmptyState art="bus" title={uiStrings.timetableEmpty} message={uiStrings.homeNoTimeHint} />
      ) : (
        <>
          {upcoming ? (
            <View
              accessibilityLabel={`${uiStrings.nextDepartureHero}: ${upcoming}`}
              style={[styles.next, { backgroundColor: t.colors.surfaceSunken, borderColor: t.colors.line }]}>
              <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>{uiStrings.nextDepartureHero}</Text>
              <Text style={t.text.display}>{upcoming}</Text>
            </View>
          ) : null}
          {groups.map((g) => (
            <View key={g.hour} style={styles.group}>
              <Text style={[t.text.headline, styles.hour]}>{g.hour}h</Text>
              <View style={styles.chips}>
                {g.times.map((time) => {
                  const past = time <= clock;
                  const isNext = time === upcoming;
                  return (
                    <View
                      key={time}
                      accessibilityLabel={isNext ? `${time}, ${uiStrings.nextDepartureHero}` : time}
                      style={[
                        styles.time,
                        {
                          backgroundColor: isNext ? t.colors.primary : t.colors.surfaceSunken,
                          borderColor: t.colors.line,
                          opacity: past && !isNext ? 0.45 : 1,
                        },
                      ]}>
                      <Text
                        style={[
                          t.text.clock,
                          { color: isNext ? t.colors.onPrimary : t.colors.ink },
                        ]}>
                        {time}
                      </Text>
                    </View>
                  );
                })}
              </View>
            </View>
          ))}
        </>
      )}
      <Text style={[t.text.caption, { color: t.colors.inkMuted, marginTop: 16 }]}>
        {`${uiStrings.timetableFootnote}${line.verified_at}`}
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  origins: { flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 12 },
  next: { borderWidth: 1, borderRadius: 16, padding: 16, marginTop: 16, gap: 4 },
  group: { marginTop: 16 },
  hour: { marginBottom: 8 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  time: { borderWidth: 1, borderRadius: 8, paddingHorizontal: 10, paddingVertical: 8, minWidth: 64, alignItems: "center" },
});

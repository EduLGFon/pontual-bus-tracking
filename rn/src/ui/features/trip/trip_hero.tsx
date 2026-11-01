// Trip hero. Port of app/lib/ui/features/trip/trip_hero.dart.
// Big reassurance block with elapsed time in tabular figures. No map.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { LiveDot } from "../../design/components/live_dot";
import { uiStrings } from "../../strings/uiStrings";
import { formatElapsed } from "./trip_metrics";

export function TripHero({ elapsedS, lineLabel }: { elapsedS: number; lineLabel?: string }) {
  const t = useTheme();
  return (
    <View
      accessibilityRole="header"
      accessibilityLabel={`${uiStrings.tripHero}. ${formatElapsed(elapsedS)}`}
      style={[styles.hero, { backgroundColor: t.colors.surface, borderColor: t.colors.line }]}>
      <LiveDot certainty="live" size={12} />
      <Text style={t.text.headline}>{uiStrings.tripHero}</Text>
      {lineLabel ? <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{lineLabel}</Text> : null}
      <Text style={[t.text.display, styles.clock]}>{formatElapsed(elapsedS)}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { borderWidth: 1, borderRadius: 20, padding: 20, gap: 8, alignItems: "flex-start" },
  clock: { fontVariant: ["tabular-nums"] },
});

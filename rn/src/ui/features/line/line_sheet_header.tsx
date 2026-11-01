// Line sheet header. Port of app/lib/ui/features/line/line_sheet_header.dart.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { LineBadge } from "../../design/components/line_badge";
import { LiveDot } from "../../design/components/live_dot";
import { lineBadgeText, type LineVM } from "../../models/line_vm";
import { aboard, uiStrings } from "../../strings/uiStrings";

export function LineSheetHeader({ line, liveCount }: { line: LineVM; liveCount: number }) {
  const t = useTheme();
  const live = liveCount > 0;
  const subtitle = live ? `${liveCount} ${uiStrings.liveCount} · ${aboard(liveCount)}` : uiStrings.homeNoLive;
  return (
    <View style={styles.head} accessibilityLabel={`${line.name}. ${subtitle}`}>
      <LineBadge lineKey={line.key} text={lineBadgeText(line)} />
      <View style={styles.main}>
        <Text style={t.text.title} numberOfLines={2}>
          {line.name}
        </Text>
        <View style={styles.sub}>
          {live ? <LiveDot certainty="live" /> : null}
          <Text style={[t.text.caption, { color: t.colors.inkMuted }]} numberOfLines={1}>
            {subtitle}
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  head: { flexDirection: "row", alignItems: "center", gap: 12 },
  main: { flex: 1, gap: 4 },
  sub: { flexDirection: "row", alignItems: "center", gap: 6 },
});

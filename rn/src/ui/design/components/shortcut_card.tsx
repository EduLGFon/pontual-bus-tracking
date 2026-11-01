// ShortcutCard. Port of app/lib/ui/design/components/shortcut_card.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { LineVM } from "../../models/line_vm";
import { lineBadgeText } from "../../models/line_vm";
import { uiStrings } from "../../strings/uiStrings";
import { LineBadge } from "./line_badge";
import { LiveDot } from "./live_dot";
import { Pressable } from "./pressable";
import { DashedOutline } from "./dashed_outline";

export function ShortcutCard({
  label,
  line,
  statusText,
  isLive = false,
  direction,
  onPress,
  onLongPress,
}: {
  label: string;
  line: LineVM;
  statusText?: string;
  isLive?: boolean;
  direction?: string;
  onPress?: () => void;
  onLongPress?: () => void;
}) {
  const t = useTheme();
  return (
    <Pressable
      onPress={onPress}
      onLongPress={onLongPress}
      accessibilityLabel={`${label}. ${statusText ?? ""}`}
      borderRadius={16}
      minSize={112}>
      <View style={[styles.card, { backgroundColor: t.colors.surface, borderColor: t.colors.line }]}>
        <View style={styles.top}>
          {isLive ? <LiveDot certainty="live" /> : null}
          <Text style={[t.text.bodyStrong, styles.label]} numberOfLines={2}>
            {label}
          </Text>
        </View>
        <LineBadge lineKey={line.key} text={lineBadgeText(line)} size="s" />
        {direction != null ? (
          <Text style={[t.text.caption, { color: t.colors.inkMuted }]} numberOfLines={1}>
            {direction}
          </Text>
        ) : null}
        <Text style={[t.text.label, { color: isLive ? t.colors.liveText : t.colors.ink }]} numberOfLines={1}>
          {statusText ?? (isLive ? uiStrings.certaintyLive : uiStrings.homeNoTime)}
        </Text>
      </View>
    </Pressable>
  );
}

export function ShortcutCardEmpty({ onPress }: { onPress?: () => void }) {
  return (
    <Pressable onPress={onPress} accessibilityLabel={uiStrings.addShortcut} borderRadius={16} minSize={112}>
      <DashedOutline radius={16} style={styles.empty}>
        <Text>{uiStrings.addShortcut}</Text>
      </DashedOutline>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: { width: 156, minHeight: 112, borderRadius: 16, borderWidth: 1, padding: 12, gap: 6 },
  top: { flexDirection: "row", alignItems: "center", gap: 6 },
  label: { flex: 1 },
  empty: { width: 156, minHeight: 112, alignItems: "center", justifyContent: "center" },
});

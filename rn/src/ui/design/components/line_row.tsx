// LineRow. Port of app/lib/ui/design/components/line_row.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { LineVM } from "../../models/line_vm";
import { lineBadgeText } from "../../models/line_vm";
import { LineBadge } from "./line_badge";
import { LiveDot } from "./live_dot";
import { Pressable } from "./pressable";
import { uiStrings, favoriteLine, unfavoriteLine } from "../../strings/uiStrings";

export function LineRow({
  line,
  status,
  onPress,
  onToggleFavorite,
  isFavorite = false,
  semanticLabel,
}: {
  line: LineVM;
  status: string;
  onPress?: () => void;
  onToggleFavorite?: () => void;
  isFavorite?: boolean;
  semanticLabel?: string;
}) {
  const t = useTheme();
  const short = line.short ?? "";
  const starLabel = short === "" ? (isFavorite ? uiStrings.unfavorite : uiStrings.favorite) : isFavorite ? unfavoriteLine(short) : favoriteLine(short);
  return (
    <Pressable onPress={onPress} accessibilityLabel={semanticLabel ?? `${line.name}. ${status}`} borderRadius={0} minSize={72}>
      <View style={[styles.row, { borderBottomColor: t.colors.line }]}>
        <LineBadge lineKey={line.key} text={lineBadgeText(line)} />
        <View style={styles.main}>
          <Text style={t.text.headline} numberOfLines={2}>
            {line.name}
          </Text>
          <View style={styles.status}>
            {line.isLive === true ? <LiveDot certainty="live" /> : null}
            <Text style={[t.text.caption, { color: t.colors.inkMuted }]} numberOfLines={1}>
              {status}
            </Text>
          </View>
        </View>
        {onToggleFavorite != null ? (
          <Pressable onPress={onToggleFavorite} accessibilityLabel={starLabel} borderRadius={999} minSize={48}>
            <Text style={[styles.star, { color: isFavorite ? t.colors.primary : t.colors.inkMuted }]}>{isFavorite ? "★" : "☆"}</Text>
          </Pressable>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", minHeight: 72, paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, gap: 12 },
  main: { flex: 1, gap: 4 },
  status: { flexDirection: "row", alignItems: "center", gap: 6 },
  star: { fontSize: 22, padding: 8 },
});

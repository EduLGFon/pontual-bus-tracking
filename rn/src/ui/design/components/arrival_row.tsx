// Arrival row. Port of app/lib/ui/design/components/arrival_row.dart.
// Left ETA block plus subtitle; accessibility sentence reads like speech.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { ArrivalVM } from "../../models/arrival_vm";
import { formatEta } from "../../util/format_eta";

export function ArrivalRow({
  arrival,
  now,
  primary,
  secondary,
}: {
  arrival?: ArrivalVM;
  now?: Date;
  primary?: string;
  secondary?: string;
}) {
  const t = useTheme();
  const at = now ?? new Date();
  const fmt = arrival ? formatEta(arrival, at) : null;
  const p = fmt?.primary ?? primary ?? "";
  const s = fmt?.secondary ?? secondary ?? "";
  const a11y = fmt?.a11y ?? p;
  return (
    <View style={styles.row} accessibilityRole="text" accessibilityLabel={a11y}>
      <Text style={t.text.bodyStrong}>{p}</Text>
      {s ? <Text style={t.text.caption}>{s}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({ row: { flexDirection: "row", alignItems: "center", minHeight: 48, gap: 8 } });

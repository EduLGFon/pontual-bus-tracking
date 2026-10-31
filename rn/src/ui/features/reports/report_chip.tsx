// Report chip. Port of app/lib/ui/features/reports/report_chip.dart.
// At most two chips plus a +N overflow; never a bare number alone.
import React from "react";
import { Text, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { Pressable } from "../../design/components/pressable";
import type { ReportVM } from "../../models/report_vm";
import { reportCountText, reportLabel } from "./report_style";

export function ReportChip({ report, onPress }: { report: ReportVM; onPress?: () => void }) {
  const t = useTheme();
  const text = `${reportLabel(report.kind)} · ${reportCountText(report.kind, report.count)}`;
  return (
    <Pressable onPress={onPress} accessibilityLabel={text} borderRadius={999} minSize={48}>
      <Text style={[styles.chip, t.text.caption, { backgroundColor: t.colors.surfaceSunken, color: t.colors.ink }]} numberOfLines={1}>
        {text}
      </Text>
    </Pressable>
  );
}

export function ReportOverflowChip({ extra, onPress }: { extra: number; onPress?: () => void }) {
  const t = useTheme();
  const label = `+${extra}`;
  return (
    <Pressable onPress={onPress} accessibilityLabel={`Mais ${extra} sinalizações`} borderRadius={999} minSize={48}>
      <Text style={[styles.chip, t.text.caption, { backgroundColor: t.colors.surfaceSunken, color: t.colors.ink }]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: { paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999, overflow: "hidden" },
});

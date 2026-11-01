// Report strip. Port of app/lib/ui/features/reports/report_strip.dart.
// Shows at most two report chips plus a +N overflow on pilot lines.
import React from "react";
import { View, StyleSheet } from "react-native";
import type { ReportVM } from "../../models/report_vm";
import { ReportChip, ReportOverflowChip } from "./report_chip";

const maxChips = 2;

export function ReportStrip({
  reports,
  onOpen,
  onOverflow,
}: {
  reports: ReportVM[];
  onOpen?: (report: ReportVM) => void;
  onOverflow?: () => void;
}) {
  if (reports.length === 0) return null;
  const shown = reports.slice(0, maxChips);
  const extra = reports.length - shown.length;
  return (
    <View style={styles.row} accessibilityLabel={`${reports.length} sinalizações`}>
      {shown.map((r) => (
        <ReportChip key={`${r.kind}:${r.area ?? "-"}`} report={r} onPress={() => onOpen?.(r)} />
      ))}
      {extra > 0 ? <ReportOverflowChip extra={extra} onPress={onOverflow} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({ row: { flexDirection: "row", flexWrap: "wrap", gap: 8 } });

// Report detail sheet. Port of app/lib/ui/features/reports/report_detail_sheet.dart.
// Shows rounded distance ("cerca de 100 m") or a fixed 150 m area note.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { PontualSheet } from "../../design/components/pontual_sheet";
import { agoShort } from "../../strings/uiStrings";
import type { ReportVM } from "../../models/report_vm";
import { reportCountText, reportLabel } from "./report_style";

function roundedDistance(m: number): string {
  if (m < 150) return "cerca de 100 m";
  if (m < 350) return "cerca de 300 m";
  if (m < 750) return "cerca de 500 m";
  return "a mais de 500 m";
}

export function ReportDetailSheet({ report }: { report: ReportVM }) {
  const t = useTheme();
  const distance =
    report.distanceM != null ? roundedDistance(report.distanceM) : "Área aproximada de 150 m";
  return (
    <PontualSheet title={reportLabel(report.kind)}>
      <View style={styles.body}>
        <Text style={t.text.headline}>{reportCountText(report.kind, report.count)}</Text>
        <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{distance}</Text>
        <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>
          {`Atualizado ${agoShort(report.updatedAgeS)}`}
        </Text>
      </View>
    </PontualSheet>
  );
}

const styles = StyleSheet.create({ body: { gap: 8 } });

// Line expanded panel. Port of app/lib/ui/features/line/line_expanded.dart.
// Side panel replacing the sheet on wide windows: same content, no drag.
import React from "react";
import { ScrollView, StyleSheet } from "react-native";
import type { StaticLine } from "../../../data/static/staticData";
import type { LineVM } from "../../models/line_vm";
import type { ReportVM } from "../../models/report_vm";
import type { VehicleVM } from "../../models/vehicle_vm";
import type { ArrivalVM } from "../../models/arrival_vm";
import { LineSheet, type LineTab } from "./line_sheet";

export function LineExpanded(props: {
  line: StaticLine;
  lineVM: LineVM;
  liveCount: number;
  vehicles: VehicleVM[];
  arrivals: ArrivalVM[];
  reports: ReportVM[];
  tab: LineTab;
  onTab: (t: LineTab) => void;
  onToggleFavorite: () => void;
  isFavorite: boolean;
}) {
  return (
    <ScrollView style={styles.root}>
      <LineSheet {...props} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({ root: { flex: 1 } });

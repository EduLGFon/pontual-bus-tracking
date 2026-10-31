// Line bottom sheet. Port of app/lib/ui/features/line/line_sheet.dart.
// Hosts the Agora (map list + reports) and Horários tabs.
import React, { useState } from "react";
import { Modal, Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { Pressable } from "../../design/components/pressable";
import { GhostLink } from "../../design/components/ghost_link";
import { VehicleRow } from "../../design/components/vehicle_row";
import type { StaticLine } from "../../../data/static/staticData";
import type { LineVM } from "../../models/line_vm";
import type { VehicleVM } from "../../models/vehicle_vm";
import type { ReportVM } from "../../models/report_vm";
import { uiStrings } from "../../strings/uiStrings";
import { TimetableTab } from "../timetable/timetable_tab";
import { LineSheetHeader } from "./line_sheet_header";
import { ArrivalRow } from "../../design/components/arrival_row";
import type { ArrivalVM } from "../../models/arrival_vm";
import { ReportDetailSheet } from "../reports/report_detail_sheet";
import { ReportSheet } from "../reports/report_sheet";
import { ReportStrip } from "../reports/report_strip";
import { reportActionLabel } from "../reports/report_style";

export type LineTab = "agora" | "horarios";

export function LineSheet({
  line,
  lineVM,
  liveCount,
  vehicles,
  arrivals,
  reports,
  tab,
  onTab,
  onToggleFavorite,
  isFavorite,
}: {
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
  const t = useTheme();
  const [reportOpen, setReportOpen] = useState(false);
  const [detail, setDetail] = useState<ReportVM | null>(null);
  const favLabel = isFavorite ? uiStrings.unfavorite : uiStrings.favorite;
  return (
    <View style={[styles.sheet, { backgroundColor: t.colors.surface }]}>
      <View style={styles.tabs} accessibilityRole="tablist">
        <TabButton label={uiStrings.tabNow} selected={tab === "agora"} onPress={() => onTab("agora")} />
        <TabButton label={uiStrings.tabTimetable} selected={tab === "horarios"} onPress={() => onTab("horarios")} />
      </View>
      <LineSheetHeader line={lineVM} liveCount={liveCount} />
      <View style={styles.favRow}>
        <Pressable onPress={onToggleFavorite} accessibilityLabel={favLabel} borderRadius={999} minSize={48}>
          <Text style={[t.text.label, { color: isFavorite ? t.colors.primary : t.colors.inkMuted }]}>
            {isFavorite ? "★ " : "☆ "}
            {favLabel}
          </Text>
        </Pressable>
      </View>
      {tab === "agora" ? (
        <View style={styles.tab}>
          {line.pilot ? (
            <View style={styles.reports}>
              <ReportStrip reports={reports} onOpen={setDetail} onOverflow={() => setDetail(reports[0] ?? null)} />
              <GhostLink label={reportActionLabel} onPress={() => setReportOpen(true)} />
            </View>
          ) : null}
          {vehicles.length === 0 ? (
            <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{uiStrings.lineNoTracking}</Text>
          ) : (
            vehicles.map((v) => <VehicleRow key={v.key} vehicle={v} />)
          )}
          {arrivals.length > 0 ? (
            <View style={styles.arrivals} accessibilityRole="list" accessibilityLabel={uiStrings.nextDepartures}>
              <Text style={[t.text.label, { color: t.colors.inkMuted }]}>{uiStrings.nextDepartures}</Text>
              {arrivals.map((a, i) => (
                <ArrivalRow key={`${a.at.getTime()}-${i}`} arrival={a} />
              ))}
            </View>
          ) : null}
        </View>
      ) : (
        <View style={styles.tab}>
          <TimetableTab line={line} />
        </View>
      )}
      <Modal visible={reportOpen} animationType="slide" onRequestClose={() => setReportOpen(false)}>
        <View style={[styles.modal, { backgroundColor: t.colors.bg }]}>
          <ReportSheet lineId={line.id} onDone={() => setReportOpen(false)} />
        </View>
      </Modal>
      <Modal visible={detail != null} animationType="slide" onRequestClose={() => setDetail(null)}>
        <View style={[styles.modal, { backgroundColor: t.colors.bg }]}>
          {detail ? <ReportDetailSheet report={detail} /> : null}
        </View>
      </Modal>
    </View>
  );
}

function TabButton({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityLabel={label} borderRadius={999} minSize={48}>
      <View
        accessibilityRole="tab"
        accessibilityState={{ selected }}
        style={[styles.tabBtn, selected ? { backgroundColor: t.colors.primary } : null]}>
        <Text style={[t.text.label, { color: selected ? t.colors.onPrimary : t.colors.inkMuted }]}>{label}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  sheet: { borderTopLeftRadius: 24, borderTopRightRadius: 24, paddingHorizontal: 16, paddingTop: 8, paddingBottom: 32 },
  tabs: { flexDirection: "row", gap: 8, paddingVertical: 8 },
  tabBtn: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: 999 },
  favRow: { alignItems: "flex-start", marginTop: 4 },
  tab: { marginTop: 12, gap: 8 },
  arrivals: { marginTop: 8, gap: 4 },
  reports: { gap: 8 },
  modal: { flex: 1, paddingTop: 48, paddingHorizontal: 16 },
});

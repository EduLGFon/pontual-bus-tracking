// Report sheet. Port of app/lib/ui/features/reports/report_sheet.dart.
// Four closed options, no free text, no photos, no votes. Waiting and
// blocked read device location once (coarse ~150 m cell on-device).
import React, { useState } from "react";
import { Linking, Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { PontualSheet } from "../../design/components/pontual_sheet";
import { Pressable } from "../../design/components/pressable";
import type { ReportKind } from "../../../domain/reporting/reportKind";
import { requiresArea } from "../../../domain/reporting/reportKind";
import { busApi } from "../../../data/api/busApi";
import { acquireReportArea } from "../../../features/reports/reportLocation";
import { geolocatorPermissionGateway } from "../../../platform/android/permissionGateway";
import { uiStrings } from "../../strings/uiStrings";
import { reportLabel } from "./report_style";

const options: ReportKind[] = ["waiting", "full", "broken", "blocked"];

type SheetState =
  | { name: "pick" }
  | { name: "sending" }
  | { name: "done" }
  | { name: "error"; message: string }
  | { name: "location"; reason: string };

export function ReportSheet({ lineId, onDone }: { lineId: number; onDone?: () => void }) {
  const t = useTheme();
  const [state, setState] = useState<SheetState>({ name: "pick" });

  async function send(kind: ReportKind) {
    setState({ name: "sending" });
    try {
      const reg = await busApi.getOrCreateToken();
      if (!reg.ok) {
        setState({ name: "error", message: uiStrings.shareNoConnection });
        return;
      }
      let area: string | undefined;
      if (requiresArea(kind)) {
        const loc = await acquireReportArea(geolocatorPermissionGateway);
        if (!loc.ok) {
          setState({ name: "location", reason: loc.reason });
          return;
        }
        area = loc.areaId;
      }
      const r = await busApi.postReport(reg.value, { op: "report", kind, lineId, area });
      if (!r.ok) {
        setState({ name: "error", message: uiStrings.shareNoConnection });
        return;
      }
      setState({ name: "done" });
      onDone?.();
    } catch {
      setState({ name: "error", message: uiStrings.genericError });
    }
  }

  return (
    <PontualSheet title="Sinalizar" scrollable>
      {state.name === "pick" || state.name === "sending" ? (
        <View style={styles.list}>
          {options.map((kind) => (
            <Pressable
              key={kind}
              onPress={() => void send(kind)}
              accessibilityLabel={reportLabel(kind)}
              borderRadius={12}
              minSize={56}>
              <View style={[styles.option, { borderColor: t.colors.line }]}>
                <Text style={t.text.bodyStrong}>{reportLabel(kind)}</Text>
              </View>
            </Pressable>
          ))}
          {state.name === "sending" ? (
            <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>Enviando…</Text>
          ) : null}
        </View>
      ) : state.name === "done" ? (
        <Text style={t.text.body}>{uiStrings.ok}</Text>
      ) : state.name === "location" ? (
        <View style={styles.list}>
          <Text style={t.text.body}>{locationMessage(state.reason)}</Text>
          <Pressable
            onPress={() => Linking.openSettings()}
            accessibilityLabel={uiStrings.openSettings}
            borderRadius={12}
            minSize={48}>
            <Text style={[t.text.label, { color: t.colors.primary }]}>{uiStrings.openSettings}</Text>
          </Pressable>
        </View>
      ) : (
        <Text style={[t.text.body, { color: t.colors.danger ?? t.colors.ink }]}>{state.message}</Text>
      )}
    </PontualSheet>
  );
}

function locationMessage(reason: string): string {
  switch (reason) {
    case "servicesOff":
      return uiStrings.locationOff;
    case "blocked":
    case "denied":
      return uiStrings.permissionDenied;
    case "imprecise":
      return uiStrings.impreciseLocation;
    default:
      return uiStrings.genericError;
  }
}

const styles = StyleSheet.create({
  list: { gap: 8 },
  option: { borderWidth: 1, borderRadius: 12, padding: 16 },
});

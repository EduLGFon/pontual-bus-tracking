// Trip status block. Port of app/lib/ui/features/trip/trip_status.dart.
// Connection, GPS, role at a glance. Live region for screen readers.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { uiStrings } from "../../strings/uiStrings";
import { roleLabel } from "./trip_metrics";

export function TripStatus({
  connected,
  gpsGood,
  role,
}: {
  connected: boolean;
  gpsGood: boolean;
  role?: string | null;
}) {
  const t = useTheme();
  return (
    <View
      accessibilityLiveRegion="polite"
      style={[styles.card, { backgroundColor: t.colors.surfaceSunken, borderColor: t.colors.line }]}>
      <StatusLine label={uiStrings.connection} value={connected ? uiStrings.connected : uiStrings.dockReconnecting} ok={connected} />
      <StatusLine label={uiStrings.gps} value={gpsGood ? uiStrings.gpsGood : uiStrings.dockGpsOff} ok={gpsGood} />
      <StatusLine label="Papel" value={roleLabel(role)} ok={true} />
    </View>
  );
}

function StatusLine({ label, value, ok }: { label: string; value: string; ok: boolean }) {
  const t = useTheme();
  return (
    <View style={styles.line}>
      <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>{label}</Text>
      <Text style={[t.text.bodyStrong, { color: ok ? t.colors.liveText : t.colors.warningText }]}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: 16, padding: 16, gap: 8 },
  line: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
});

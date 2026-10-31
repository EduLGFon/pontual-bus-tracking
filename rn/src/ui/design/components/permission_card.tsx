// PermissionCard. Port of app/lib/ui/design/components/permission_card.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { uiStrings } from "../../strings/uiStrings";
import { SurfaceCard } from "./surface_card";
import { GhostLink } from "./ghost_link";

export type PermissionCardState =
  | "denied"
  | "blocked"
  | "imprecise"
  | "servicesOff"
  | "browserBlocked"
  | "notificationsDenied"
  | "unsupported";

const messages: Record<PermissionCardState, string> = {
  denied: uiStrings.permissionDenied,
  blocked: uiStrings.permissionDenied,
  imprecise: uiStrings.impreciseLocation,
  servicesOff: uiStrings.locationOff,
  browserBlocked: uiStrings.locationOff,
  notificationsDenied: uiStrings.locationOff,
  unsupported: uiStrings.unsupported,
};

export function PermissionCard({
  state,
  onRetry,
  onOpenSettings,
  onOpenLines,
}: {
  state: PermissionCardState;
  onRetry?: () => void;
  onOpenSettings?: () => void;
  onOpenLines?: () => void;
}) {
  const t = useTheme();
  void onOpenLines;
  return (
    <SurfaceCard accessibilityLabel={`${uiStrings.permissionDenied}. ${messages[state]}`}>
      <View style={styles.row}>
        <Text style={[styles.lock, { color: t.colors.warningText }]}>◈</Text>
        <Text style={[t.text.bodyStrong, styles.title]}>{uiStrings.permissionDenied}</Text>
      </View>
      <Text style={[t.text.body, styles.body]}>{messages[state]}</Text>
      <View style={styles.actions}>
        {onRetry != null ? <GhostLink label={uiStrings.retry} onPress={onRetry} /> : null}
        {(state === "blocked" || state === "denied") && onOpenSettings != null ? (
          <GhostLink label={uiStrings.openSettings} onPress={onOpenSettings} />
        ) : null}
      </View>
    </SurfaceCard>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", gap: 8, minHeight: 24 },
  title: { flex: 1 },
  lock: { fontSize: 20 },
  body: { marginTop: 12 },
  actions: { flexDirection: "row", marginTop: 16, gap: 8 },
});

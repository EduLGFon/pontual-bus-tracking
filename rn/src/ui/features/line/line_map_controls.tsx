// Line map controls. Port of app/lib/ui/features/line/line_map_controls.dart.
// Follow toggle, my-location button, and the status row (live/stale/no
// vehicles/connecting/offline) as text, never color alone.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { LiveDot } from "../../design/components/live_dot";
import { Pressable } from "../../design/components/pressable";
import { uiStrings } from "../../strings/uiStrings";

export type MapStatus = "live" | "stale" | "empty" | "connecting" | "offline";

export function statusText(status: MapStatus, count: number): string {
  switch (status) {
    case "live":
      return `${count} ${uiStrings.vehiclesNow}`;
    case "stale":
      return uiStrings.noSignal;
    case "empty":
      return uiStrings.lineNoTracking;
    case "connecting":
      return uiStrings.mapLoading;
    case "offline":
      return uiStrings.homeOffline;
  }
}

export function LineMapControls({
  status,
  count,
  following,
  onToggleFollow,
  onLocate,
  locating,
}: {
  status: MapStatus;
  count: number;
  following: boolean;
  onToggleFollow: () => void;
  onLocate: () => void;
  locating: boolean;
}) {
  const t = useTheme();
  return (
    <View style={styles.root}>
      <View
        accessibilityLabel={`${uiStrings.mapOfLine}: ${statusText(status, count)}`}
        style={[styles.status, { backgroundColor: t.colors.surfaceSunken, borderColor: t.colors.line }]}>
        <LiveDot certainty={status === "live" ? "live" : "stale"} />
        <Text style={[t.text.caption]} numberOfLines={2}>
          {statusText(status, count)}
        </Text>
      </View>
      <View style={styles.buttons}>
        <Pressable
          onPress={onToggleFollow}
          accessibilityLabel={following ? uiStrings.stopFollowing : uiStrings.follow}
          borderRadius={999}
          minSize={48}>
          <Text style={[styles.btn, { backgroundColor: t.colors.surfaceRaised, color: t.colors.primary }]}>
            {following ? uiStrings.following : uiStrings.follow}
          </Text>
        </Pressable>
        <Pressable
          onPress={onLocate}
          accessibilityLabel={uiStrings.myLocation}
          borderRadius={999}
          minSize={48}>
          <Text style={[styles.btn, { backgroundColor: t.colors.surfaceRaised, color: t.colors.primary }]}>
            {locating ? "…" : "◎"}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 8 },
  status: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
    alignSelf: "flex-start",
    maxWidth: "100%",
  },
  buttons: { flexDirection: "row", gap: 8 },
  btn: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 999, overflow: "hidden", fontSize: 14 },
});

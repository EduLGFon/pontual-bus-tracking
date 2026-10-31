// System screens. Port of app/lib/ui/features/system/system_screen.dart.
// Blocking states: maintenance, update required, server unavailable,
// not found. Timetables stay usable where applicable.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { EmptyState } from "../../design/components/empty_state";
import { uiStrings } from "../../strings/uiStrings";

export type SystemKind = "maintenance" | "update" | "serverDown" | "notFound";

export function systemKindOf(raw: string | undefined): SystemKind {
  switch (raw) {
    case "update":
      return "update";
    case "serverDown":
      return "serverDown";
    case "notFound":
      return "notFound";
    default:
      return "maintenance";
  }
}

export function SystemScreen({ kind, message }: { kind: SystemKind; message?: string }) {
  const t = useTheme();
  const router = useRouter();
  const title =
    kind === "maintenance"
      ? uiStrings.maintenanceTitle
      : kind === "update"
        ? uiStrings.updateTitle
        : kind === "serverDown"
          ? uiStrings.serverDownTitle
          : uiStrings.notFoundTitle;
  const body =
    message != null && message !== ""
      ? message
      : kind === "maintenance"
        ? uiStrings.maintenanceBody
        : uiStrings.serverDownBody;
  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <EmptyState
        art="wrench"
        title={title}
        message={body}
        actionLabel={uiStrings.back}
        onAction={() => router.replace("/")}
      />
    </View>
  );
}

const styles = StyleSheet.create({ root: { flex: 1, justifyContent: "center", padding: 16 } });

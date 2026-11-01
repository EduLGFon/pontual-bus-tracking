// Line not found. Port of app/lib/ui/features/line/line_not_found.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { EmptyState } from "../../design/components/empty_state";
import { uiStrings } from "../../strings/uiStrings";

export function LineNotFound() {
  const t = useTheme();
  const router = useRouter();
  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <EmptyState
        art="search"
        title={uiStrings.lineNotFound}
        message={uiStrings.linesNoTimetableBody}
        actionLabel={uiStrings.back}
        onAction={() => router.replace("/")}
      />
    </View>
  );
}

const styles = StyleSheet.create({ root: { flex: 1, justifyContent: "center", padding: 16 } });

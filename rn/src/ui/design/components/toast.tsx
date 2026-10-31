// Toast. Port of app/lib/ui/design/components/toast.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export function Toast({
  message,
  actionLabel,
  onAction,
  visible = true,
}: {
  message: string;
  actionLabel?: string;
  onAction?: () => void;
  visible?: boolean;
}) {
  const t = useTheme();
  if (!visible) return null;
  return (
    <View style={styles.slot}>
      <View style={[styles.toast, { backgroundColor: t.colors.surfaceRaised, borderColor: t.colors.line }]}>
        <Text style={[t.text.body, styles.msg]} numberOfLines={1}>
          {message}
        </Text>
        {actionLabel != null && onAction != null ? (
          <Pressable onPress={onAction} accessibilityLabel={actionLabel} borderRadius={8} minSize={48}>
            <Text style={[t.text.label, { color: t.colors.primary }]}>{actionLabel}</Text>
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  slot: { paddingHorizontal: 20, alignItems: "center" },
  toast: { flexDirection: "row", alignItems: "center", borderWidth: 1, borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12, gap: 8, minHeight: 48 },
  msg: { flex: 1 },
});

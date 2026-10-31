// Toast host. Port of app/lib/ui/shell/toast_host.dart.
import React from "react";
import { View, Text } from "react-native";
import { useTheme } from "../design/theme/context";

export function ToastHost({ message }: { message?: string | null }) {
  const t = useTheme();
  if (!message) return null;
  return (
    <View style={{ backgroundColor: t.colors.surfaceRaised, padding: 12, borderRadius: 12 }}>
      <Text style={{ color: t.colors.ink }}>{message}</Text>
    </View>
  );
}
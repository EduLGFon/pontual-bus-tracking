// Offline bridge. Port of app/lib/ui/shell/offline_bridge.dart.
import React from "react";
import { View, Text } from "react-native";
import { useTheme } from "../design/theme/context";

export function OfflineBridge({ offline }: { offline: boolean }) {
  const t = useTheme();
  if (!offline) return null;
  return (
    <View style={{ backgroundColor: t.colors.warning, padding: 8 }}>
      <Text style={{ color: t.colors.warningText }}>Sem conexão. Mostrando dados salvos.</Text>
    </View>
  );
}
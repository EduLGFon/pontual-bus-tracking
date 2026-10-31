// App shell. Port of app/lib/ui/shell/app_shell.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../design/theme/context";

export function AppShell({ children }: { children: React.ReactNode }) {
  const t = useTheme();
  return <View style={[styles.root, { backgroundColor: t.colors.bg }]}>{children}</View>;
}

const styles = StyleSheet.create({ root: { flex: 1 } });
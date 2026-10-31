// Route and terminal glyphs. Port of app/lib/ui/design/icons/route_icon.dart.
import React from "react";
import { View, StyleSheet } from "react-native";

export function RouteIcon({ size = 24, color }: { size?: number; color: string }) {
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Rota"
      style={[styles.root, { width: size, height: size }]}>
      <View style={[styles.dot, { backgroundColor: color }]} />
      <View style={[styles.path, { borderColor: color }]} />
      <View style={[styles.flag, { borderColor: color }]} />
    </View>
  );
}

export function TerminalIcon({ size = 24, color }: { size?: number; color: string }) {
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel="Terminal"
      style={[styles.root, { width: size, height: size }]}>
      <View style={[styles.post, { backgroundColor: color }]} />
      <View style={[styles.bar, { backgroundColor: color }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { alignItems: "center", justifyContent: "center" },
  dot: { width: 6, height: 6, borderRadius: 999, position: "absolute", left: 3, bottom: 3 },
  path: { width: "50%", height: "62%", borderWidth: 1.75, borderRightColor: "transparent", borderBottomColor: "transparent", borderTopLeftRadius: 8, position: "absolute", left: 5, top: 4 },
  flag: { width: 8, height: 7, borderWidth: 1.75, borderLeftColor: "transparent", borderBottomColor: "transparent", position: "absolute", right: 3, top: 3 },
  post: { width: 2, height: "75%" },
  bar: { width: "42%", height: 2, position: "absolute", top: "12%" },
});

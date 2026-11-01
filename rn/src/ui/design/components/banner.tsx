import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function Banner({ text }: { text?: string }) {
  const t = useTheme();
  return (
    <View style={[styles.root, { backgroundColor: t.colors.surfaceSunken }]}>
      <Text style={t.text.body}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({ root: { padding: 12, borderRadius: 12 } });
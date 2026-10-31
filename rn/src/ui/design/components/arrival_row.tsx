import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function ArrivalRow({ primary, secondary }: { primary?: string; secondary?: string }) {
  const t = useTheme();
  return (
    <View style={styles.row}>
      <Text style={t.text.bodyStrong}>{primary}</Text>
      {secondary ? <Text style={t.text.caption}>{secondary}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({ row: { flexDirection: "row", alignItems: "center", minHeight: 48, gap: 8 } });
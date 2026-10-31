// PredictedPath. Port of app/lib/ui/design/components/predicted_path.dart.
// Renders a dashed connector strip; the map layer projects real points.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { uiStrings } from "../../strings/uiStrings";

export function PredictedPath({ height = 72 }: { points?: { x: number; y: number }[]; height?: number }) {
  const t = useTheme();
  return (
    <View accessibilityLabel={uiStrings.ghostPredictionLabel} style={[styles.root, { height }]}>
      <View style={[styles.dash, { borderTopColor: t.colors.predicted }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { justifyContent: "center" },
  dash: { borderTopWidth: 3, borderStyle: "dashed" },
});

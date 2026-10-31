// ReliabilityCard. Port of app/lib/ui/design/components/reliability_card.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { typicalDelayOf } from "../../strings/uiStrings";
import { SurfaceCard } from "./surface_card";
import { Sparkline } from "./sparkline";

export function ReliabilityCard({
  typicalDelayMin,
  bars,
  sampleSize,
}: {
  typicalDelayMin: number;
  bars: number[];
  sampleSize: number;
}) {
  const t = useTheme();
  if (sampleSize <= 0) return null;
  return (
    <SurfaceCard>
      <View style={styles.col}>
        <Text style={t.text.bodyStrong}>{typicalDelayOf(typicalDelayMin)}</Text>
        <Sparkline bars={bars} />
      </View>
    </SurfaceCard>
  );
}

const styles = StyleSheet.create({ col: { gap: 8 } });

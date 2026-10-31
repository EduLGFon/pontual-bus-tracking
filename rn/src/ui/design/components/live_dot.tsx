// LiveDot. Port of app/lib/ui/design/components/live_dot.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import type { Certainty } from "../../models/certainty";

const labels: Record<Certainty, string> = {
  live: "Ao vivo",
  predicted: "Previsão",
  scheduled: "Horário",
  stale: "Sem sinal",
};

export function LiveDot({ certainty, size = 8 }: { certainty: Certainty; size?: number }) {
  const t = useTheme();
  const fill = t.colors.graphicOf(certainty);
  const filled = certainty === "live";
  return (
    <View
      accessibilityRole="image"
      accessibilityLabel={labels[certainty]}
      style={[styles.hit, { width: size * 3, height: size * 3 }]}>
      <View
        style={[
          styles.dot,
          {
            width: size,
            height: size,
            borderRadius: size / 2,
            backgroundColor: filled ? fill : "transparent",
            borderColor: fill,
            borderWidth: filled ? 0 : size * 0.25,
          },
        ]}
      />
      {filled ? <View style={[styles.ring, { width: size * 2, height: size * 2, borderRadius: size, borderColor: fill }]} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  hit: { alignItems: "center", justifyContent: "center" },
  dot: { zIndex: 1 },
  ring: { position: "absolute", borderWidth: 1.5, opacity: 0.4 },
});

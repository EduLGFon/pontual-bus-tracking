// EtaText. Port of app/lib/ui/design/components/eta_text.dart.
import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function EtaText({
  primary,
  secondary,
  hero = false,
  dimmed = false,
  semanticLabel,
}: {
  primary: string;
  secondary?: string;
  hero?: boolean;
  dimmed?: boolean;
  semanticLabel?: string;
}) {
  const t = useTheme();
  const primaryStyle = hero ? t.text.etaHero : t.text.etaLarge;
  return (
    <View accessibilityLabel={semanticLabel} style={styles.col}>
      <Text style={[primaryStyle, dimmed ? { opacity: 0.55 } : null]} numberOfLines={1}>
        {primary}
      </Text>
      {secondary != null ? <Text style={[t.text.caption, dimmed ? { opacity: 0.55 } : null]}>{secondary}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({ col: { minHeight: 48, justifyContent: "center" } });

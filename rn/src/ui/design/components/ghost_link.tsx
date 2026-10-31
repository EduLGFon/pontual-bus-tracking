// GhostLink. Port of app/lib/ui/design/components/ghost_link.dart.
import React from "react";
import { Text, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export function GhostLink({ label, onPress, color }: { label: string; onPress?: () => void; color?: string }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityLabel={label} borderRadius={999}>
      <Text style={[styles.text, t.text.label, { color: color ?? t.colors.primary }]} numberOfLines={1}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({ text: { paddingHorizontal: 12, paddingVertical: 8 } });

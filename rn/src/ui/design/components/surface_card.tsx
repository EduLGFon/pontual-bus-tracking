// SurfaceCard. Port of app/lib/ui/design/components/surface_card.dart.
import React from "react";
import { StyleSheet, View, type ViewStyle } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export function SurfaceCard({
  onPress,
  onLongPress,
  padding = 16,
  borderRadius = 16,
  selected = false,
  accessibilityLabel,
  sunken = false,
  style,
  children,
}: {
  onPress?: () => void;
  onLongPress?: () => void;
  padding?: number;
  borderRadius?: number;
  selected?: boolean;
  accessibilityLabel?: string;
  sunken?: boolean;
  style?: ViewStyle;
  children: React.ReactNode;
}) {
  const t = useTheme();
  const card = (
    <View
      style={[
        styles.card,
        {
          backgroundColor: sunken ? t.colors.surfaceSunken : t.colors.surface,
          borderColor: selected ? t.colors.primary : t.colors.line,
          borderRadius,
          padding,
        },
        style,
      ]}>
      {children}
    </View>
  );
  if (onPress == null && onLongPress == null) return card;
  return (
    <Pressable onPress={onPress} onLongPress={onLongPress} accessibilityLabel={accessibilityLabel} borderRadius={borderRadius}>
      {card}
    </Pressable>
  );
}

const styles = StyleSheet.create({ card: { borderWidth: 1 } });

// Pressable: interaction base. Port of app/lib/ui/design/components/pressable.dart.
import React, { useState } from "react";
import { Pressable as RNPressable, StyleSheet, type ViewStyle } from "react-native";
import { useTheme } from "../theme/context";

export function Pressable({
  onPress,
  onLongPress,
  accessibilityLabel,
  isButton = true,
  minSize = 48,
  borderRadius = 12,
  enabled = true,
  style,
  children,
}: {
  onPress?: () => void;
  onLongPress?: () => void;
  accessibilityLabel?: string;
  isButton?: boolean;
  minSize?: number;
  borderRadius?: number;
  enabled?: boolean;
  style?: ViewStyle;
  children: React.ReactNode;
}) {
  const t = useTheme();
  const [pressed, setPressed] = useState(false);
  const interactive = enabled && onPress != null;
  return (
    <RNPressable
      onPress={interactive ? onPress : undefined}
      onLongPress={onLongPress}
      onPressIn={() => setPressed(true)}
      onPressOut={() => setPressed(false)}
      accessibilityRole={isButton ? "button" : undefined}
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ disabled: !interactive }}
      disabled={!interactive && onLongPress == null}
      style={[
        styles.base,
        { minWidth: minSize, minHeight: minSize, borderRadius, backgroundColor: pressed ? t.colors.line : "transparent" },
        style,
      ]}>
      {children}
    </RNPressable>
  );
}

const styles = StyleSheet.create({ base: { justifyContent: "center" } });

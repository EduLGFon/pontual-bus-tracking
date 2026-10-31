// IconBtn. Port of app/lib/ui/design/components/icon_btn.dart.
import React from "react";
import { View, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";

export function IconBtn({
  semanticLabel,
  onPress,
  size = 48,
  selected = false,
  filled = false,
  children,
}: {
  semanticLabel: string;
  onPress?: () => void;
  size?: number;
  selected?: boolean;
  filled?: boolean;
  children: React.ReactNode;
}) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityLabel={semanticLabel} borderRadius={999} minSize={size}>
      <View
        style={[
          styles.circle,
          {
            width: size,
            height: size,
            backgroundColor: filled ? t.colors.surfaceSunken : selected ? t.colors.line : "transparent",
          },
        ]}>
        {children}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({ circle: { borderRadius: 999, alignItems: "center", justifyContent: "center" } });

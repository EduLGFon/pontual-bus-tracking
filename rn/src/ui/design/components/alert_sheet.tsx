import React from "react";
import { View, Text, Pressable, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";

export function AlertSheet({ title, body, onClose }: { title?: string; body?: string; onClose?: () => void }) {
  const t = useTheme();
  return (
    <View style={[styles.root, { backgroundColor: t.colors.surface }]}>
      {title ? <Text style={t.text.title}>{title}</Text> : null}
      {body ? <Text style={t.text.body}>{body}</Text> : null}
      <Pressable onPress={onClose} accessibilityRole="button" accessibilityLabel="Fechar" style={styles.btn}>
        <Text style={t.text.label}>Fechar</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({ root: { padding: 16, borderRadius: 16 }, btn: { minHeight: 48, justifyContent: "center" } });
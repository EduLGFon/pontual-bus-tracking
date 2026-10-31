// SearchField. Port of app/lib/ui/design/components/search_field.dart.
import React, { useState } from "react";
import { View, Text, TextInput, StyleSheet } from "react-native";
import { useTheme } from "../theme/context";
import { Pressable } from "./pressable";
import { uiStrings } from "../../strings/uiStrings";

export function SearchField({
  hint,
  value,
  onChange,
  onSubmit,
  autoFocus = false,
  semanticLabel,
}: {
  hint: string;
  value?: string;
  onChange?: (v: string) => void;
  onSubmit?: (v: string) => void;
  autoFocus?: boolean;
  semanticLabel?: string;
}) {
  const t = useTheme();
  const [inner, setInner] = useState("");
  const text = value ?? inner;
  const set = (v: string) => {
    if (value === undefined) setInner(v);
    onChange?.(v);
  };
  return (
    <View
      accessibilityLabel={semanticLabel ?? hint}
      accessibilityRole="search"
      style={[styles.box, { backgroundColor: t.colors.surfaceSunken }]}>
      <Text style={[styles.icon, { color: t.colors.inkMuted }]}>○</Text>
      <TextInput
        value={text}
        onChangeText={set}
        onSubmitEditing={(e) => onSubmit?.(e.nativeEvent.text)}
        placeholder={hint}
        placeholderTextColor={t.colors.inkSubtle}
        autoFocus={autoFocus}
        returnKeyType="search"
        accessibilityLabel={semanticLabel ?? hint}
        style={[styles.input, t.text.body, { color: t.colors.ink }]}
      />
      {onChange != null && text !== "" ? (
        <Pressable onPress={() => set("")} accessibilityLabel={uiStrings.searchFieldClear} borderRadius={999} minSize={48}>
          <Text style={[styles.clear, { color: t.colors.inkMuted }]}>×</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function SearchEntry({ hint, onPress }: { hint: string; onPress?: () => void }) {
  const t = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityLabel={hint} borderRadius={16}>
      <View style={[styles.box, { backgroundColor: t.colors.surfaceSunken }]}>
        <Text style={[styles.icon, { color: t.colors.inkMuted }]}>○</Text>
        <Text style={[t.text.body, { color: t.colors.inkSubtle }]}>{hint}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  box: { height: 52, borderRadius: 16, paddingHorizontal: 16, flexDirection: "row", alignItems: "center", gap: 12 },
  icon: { fontSize: 20 },
  input: { flex: 1, minHeight: 48 },
  clear: { fontSize: 22, padding: 8 },
});

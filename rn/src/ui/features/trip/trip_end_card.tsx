// Trip end card. Port of app/lib/ui/features/trip/trip_end_card.dart.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton } from "../../design/components/buttons";
import { uiStrings } from "../../strings/uiStrings";

export function TripEndCard({ reason, onBack }: { reason?: string | null; onBack: () => void }) {
  const t = useTheme();
  return (
    <View style={[styles.card, { backgroundColor: t.colors.surface, borderColor: t.colors.line }]}>
      <Text style={t.text.headline}>{uiStrings.endTitle}</Text>
      {reason ? <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{reason}</Text> : null}
      <View style={{ marginTop: 8 }}>
        <PrimaryButton label={uiStrings.endBack} onPress={onBack} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: 20, padding: 20, gap: 8 },
});

// First-run affordances of home: one-time welcome card and coachmark.
// Port of app/lib/ui/features/home/first_run.dart.
import React, { useEffect } from "react";
import { Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton } from "../../design/components/buttons";
import { GhostLink } from "../../design/components/ghost_link";
import { Pressable } from "../../design/components/pressable";
import { SurfaceCard } from "../../design/components/surface_card";
import { uiStrings } from "../../strings/uiStrings";

export function WelcomeCard({ onDismiss }: { onDismiss: () => void }) {
  const t = useTheme();
  const router = useRouter();
  return (
    <SurfaceCard accessibilityLabel={uiStrings.welcomeTitle}>
      <View style={styles.row}>
        <Text style={[styles.bus, { color: t.colors.primary }]} aria-hidden={true}>
          {"🚌"}
        </Text>
        <Text style={t.text.headline}>{uiStrings.welcomeTitle}</Text>
      </View>
      <Text style={[t.text.body, { color: t.colors.inkMuted, marginTop: 12 }]}>{uiStrings.welcomeBody}</Text>
      <View style={styles.linkRow}>
        <GhostLink label={uiStrings.welcomePrivacy} onPress={() => router.push("/privacy")} />
      </View>
      <View style={{ marginTop: 8 }}>
        <PrimaryButton label={uiStrings.ok} onPress={onDismiss} />
      </View>
    </SurfaceCard>
  );
}

const coachmarkMs = 6000;

export function CoachmarkBubble({ onDismiss }: { onDismiss: () => void }) {
  const t = useTheme();
  useEffect(() => {
    const id = setTimeout(onDismiss, coachmarkMs);
    return () => clearTimeout(id);
  }, [onDismiss]);
  return (
    <Pressable onPress={onDismiss} accessibilityLabel={uiStrings.coachmark} borderRadius={16}>
      <View style={[styles.bubble, { backgroundColor: t.colors.surfaceRaised, borderColor: t.colors.line }]}>
        <Text style={t.text.label} numberOfLines={2}>
          {uiStrings.coachmark}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", alignItems: "center", gap: 12 },
  bus: { fontSize: 24 },
  linkRow: { alignItems: "flex-start", marginTop: 8 },
  bubble: {
    alignSelf: "center",
    maxWidth: 280,
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
});

// Welcome route (S02, first run only). Static, no permissions.
// "Começar" stores welcome_seen and goes home.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../ui/design/theme/context";
import { PrimaryButton } from "../ui/design/components/buttons";
import { GhostLink } from "../ui/design/components/ghost_link";
import { uiStrings } from "../ui/strings/uiStrings";
import * as storage from "../data/prefs/storage";
import { welcomeSeenKey } from "../ui/features/home/welcome_state";

export default function WelcomeRoute() {
  const t = useTheme();
  const router = useRouter();
  async function start() {
    try {
      await storage.setItem(welcomeSeenKey, "1");
    } catch {}
    router.replace("/");
  }
  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <Text style={[t.text.title, { color: t.colors.primary }]}>{uiStrings.wordmark}</Text>
      <Text style={[t.text.display, styles.title]}>{uiStrings.welcomeTitle}</Text>
      <Text style={[t.text.body, { color: t.colors.inkMuted }]}>{uiStrings.welcomeBody}</Text>
      <View style={styles.link}>
        <GhostLink label={uiStrings.welcomePrivacy} onPress={() => router.push("/privacy")} />
      </View>
      <PrimaryButton label="Começar" onPress={() => void start()} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, padding: 24, justifyContent: "center", gap: 8 },
  title: { marginTop: 16 },
  link: { alignItems: "flex-start", marginVertical: 8 },
});

// Settings screen. Port of app/lib/ui/features/settings/settings_screen.dart.
// Local-only list: theme, privacy, about, contact, version. No network.
import React, { useState } from "react";
import { Linking, ScrollView, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import Constants from "expo-constants";
import { useTheme, type ThemeMode } from "../../design/theme/context";
import { useRemoteConfigStore } from "../../../stores";
import { uiStrings } from "../../strings/uiStrings";
import { SettingsRow } from "./settings_row";
import { SettingsSection } from "./settings_section";
import { AndroidAppDownloadRow } from "./android_app_download_row";

const themeValue = (mode: ThemeMode): string =>
  mode === "system" ? uiStrings.themeSystem : mode === "light" ? uiStrings.themeLight : uiStrings.themeDark;

export function SettingsScreen() {
  const t = useTheme();
  const router = useRouter();
  const rc = useRemoteConfigStore((s) => s.config);
  const [version] = useState(() =>
    typeof Constants.expoConfig?.version === "string" && Constants.expoConfig.version !== ""
      ? Constants.expoConfig.version
      : "0.3.0",
  );

  const cycleTheme = () => {
    const next: ThemeMode = t.mode === "system" ? "light" : t.mode === "light" ? "dark" : "system";
    t.setMode(next);
  };

  return (
    <ScrollView style={[styles.root, { backgroundColor: t.colors.bg }]} contentContainerStyle={styles.content}>
      <SettingsSection title={uiStrings.sectionAppearance}>
        <SettingsRow title={uiStrings.theme} value={themeValue(t.mode)} onPress={cycleTheme} />
        <AndroidAppDownloadRow />
      </SettingsSection>
      <SettingsSection title={uiStrings.sectionPrivacyHelp}>
        <SettingsRow
          title={uiStrings.privacyPolicy}
          subtitle={uiStrings.privacySummary}
          onPress={() => router.push("/privacy")}
        />
        <SettingsRow
          title="Ajuda e contato"
          subtitle="Fale com a equipe do Pontual"
          onPress={() => void Linking.openURL("mailto:contato@pontual.exemplo")}
        />
      </SettingsSection>
      <SettingsSection title={uiStrings.sectionAbout}>
        <SettingsRow title="Sobre e fontes de dados" onPress={() => router.push("/about")} />
        <SettingsRow title="Versão" value={version} />
        {rc?.message_pt ? <SettingsRow title="Aviso" subtitle={rc.message_pt} /> : null}
      </SettingsSection>
      <View style={{ height: 48 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { paddingBottom: 32 },
});

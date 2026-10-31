// Privacy center. Port of app/lib/ui/features/settings/privacy_screen.dart.
// Bundled policy/terms (offline), 6-line summary, delete-my-data with
// confirmation, consent revocation. Honest offline errors, no fake success.
import React, { useState } from "react";
import { Alert, ScrollView, Text, StyleSheet, View } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton, SecondaryButton } from "../../design/components/buttons";
import { uiStrings } from "../../strings/uiStrings";
import { deleteMyData, revokeConsent } from "../../../features/settings/privacyActions";

const summary = [
  "Sem cadastro: só um código aleatório no aparelho.",
  "Localização só durante a viagem, só na memória do servidor.",
  "Tudo some quando a viagem acaba.",
  "Sinalizações mostram só uma área de ~150 m, por até 2 horas.",
  "Quem só olha o mapa não cria registro nenhum.",
  "Você pode apagar tudo aqui, a qualquer momento.",
];

export function PrivacyScreen() {
  const t = useTheme();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function onDelete() {
    setBusy(true);
    setMessage(null);
    try {
      const outcome = await deleteMyData();
      if (outcome === "deleted") {
        router.replace("/welcome");
      } else {
        setMessage(uiStrings.shareNoConnection);
      }
    } catch {
      setMessage(uiStrings.genericError);
    } finally {
      setBusy(false);
    }
  }

  function confirmDelete() {
    Alert.alert(uiStrings.privacyDelete, uiStrings.clearLocalDataConfirm, [
      { text: uiStrings.cancel, style: "cancel" },
      { text: uiStrings.clearLocalDataConfirm, style: "destructive", onPress: () => void onDelete() },
    ]);
  }

  async function onRevoke() {
    setBusy(true);
    try {
      await revokeConsent();
      setMessage(uiStrings.ok);
    } catch {
      setMessage(uiStrings.genericError);
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView style={[styles.root, { backgroundColor: t.colors.bg }]} contentContainerStyle={styles.content}>
      <Text style={t.text.display}>{uiStrings.settingsTitle}</Text>
      <Text style={[t.text.headline, styles.h]} accessibilityRole="header">
        O que coletamos
      </Text>
      {summary.map((line) => (
        <Text key={line} style={[t.text.body, styles.bullet]}>
          {`· ${line}`}
        </Text>
      ))}
      <View style={styles.links}>
        <SecondaryButton label={uiStrings.privacyPolicy} onPress={() => router.push("/privacy/policy")} />
        <SecondaryButton label="Termos de uso" onPress={() => router.push("/privacy/terms")} />
      </View>
      <Text style={[t.text.headline, styles.h]} accessibilityRole="header">
        Seus dados
      </Text>
      <View style={styles.actions}>
        <PrimaryButton label={busy ? "…" : uiStrings.privacyDelete} onPress={confirmDelete} />
        <SecondaryButton label="Revogar consentimento" onPress={() => void onRevoke()} />
      </View>
      {message ? <Text style={[t.text.body, styles.msg]}>{message}</Text> : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  h: { marginTop: 24, marginBottom: 8 },
  bullet: { marginTop: 4 },
  links: { gap: 8, marginTop: 16 },
  actions: { gap: 8, marginTop: 8 },
  msg: { marginTop: 12 },
});

// Consent disclosure and permission pre-prompt sheets.
// Port of app/lib/ui/features/trip/permission_sheets.dart.
// The disclosure never records anything itself: acceptance is handed to
// the share flow, which records the choice exactly once.
import React from "react";
import { Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton, SecondaryButton } from "../../design/components/buttons";
import { GhostLink } from "../../design/components/ghost_link";
import { PontualSheet } from "../../design/components/pontual_sheet";
import { uiStrings } from "../../strings/uiStrings";

const bullets = [
  uiStrings.consentBulletPurpose,
  uiStrings.consentBulletNoIdentity,
  uiStrings.consentBulletDeleted,
  uiStrings.consentBulletOthers,
  uiStrings.consentBulletControl,
];

export function ConsentBody({ onAccept, onDecline }: { onAccept: () => void; onDecline: () => void }) {
  const t = useTheme();
  const router = useRouter();
  return (
    <PontualSheet title={uiStrings.consentTitle} scrollable>
      <Text style={t.text.body}>{uiStrings.consentBody}</Text>
      <View style={styles.bullets}>
        {bullets.map((b) => (
          <View key={b} style={styles.bullet}>
            <Text style={[t.text.bodyStrong, { color: t.colors.liveText }]} aria-hidden={true}>
              {"✓ "}
            </Text>
            <Text style={[t.text.body, styles.bulletText]}>{b}</Text>
          </View>
        ))}
      </View>
      <GhostLink label={uiStrings.privacyPolicy} onPress={() => router.push("/privacy/policy")} />
      <View style={styles.actions}>
        <PrimaryButton label={uiStrings.consentAccept} onPress={onAccept} />
        <SecondaryButton label={uiStrings.consentDecline} onPress={onDecline} />
      </View>
    </PontualSheet>
  );
}

export function PermissionPromptBody({ onContinue, onCancel }: { onContinue: () => void; onCancel: () => void }) {
  const t = useTheme();
  return (
    <PontualSheet title={uiStrings.permissionPrompt}>
      <Text style={t.text.body}>{uiStrings.permissionPrompt}</Text>
      <View style={styles.actions}>
        <PrimaryButton label={uiStrings.permissionContinue} onPress={onContinue} />
        <SecondaryButton label={uiStrings.cancel} onPress={onCancel} />
      </View>
    </PontualSheet>
  );
}

const styles = StyleSheet.create({
  bullets: { marginTop: 16, gap: 8 },
  bullet: { flexDirection: "row" },
  bulletText: { flex: 1 },
  actions: { gap: 8, marginTop: 16 },
});

// Battery exemption card shown while the trip shows a lack of data.
// Port of app/lib/ui/features/trip/trip_status.dart _BatteryExemptionCard.
// Android only, user-tapped only, never blocks sharing. The card hides
// itself when the app already ignores optimizations, and the direct system
// exemption pop-up fires only from the action press (D61, D95).
import React, { useCallback, useEffect, useState } from "react";
import { Platform, Pressable, Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { uiStrings } from "../../strings/uiStrings";
import {
  isIgnoringBatteryOptimizations,
  requestIgnoreBatteryOptimizations,
  type RequestExemption,
} from "../../../platform/android/batteryOptimization";

export function BatteryExemptionCard({
  requestExemption = requestIgnoreBatteryOptimizations,
}: {
  requestExemption?: RequestExemption;
}) {
  const t = useTheme();
  const [exempt, setExempt] = useState<boolean | null>(null);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (Platform.OS !== "android") return;
    let live = true;
    void isIgnoringBatteryOptimizations()
      .then((v) => {
        if (live) setExempt(v);
      })
      .catch(() => {
        if (live) setExempt(false);
      });
    return () => {
      live = false;
    };
  }, []);

  const onRequest = useCallback(async () => {
    if (busy) return;
    setBusy(true);
    try {
      const granted = await requestExemption();
      setFeedback(
        granted
          ? uiStrings.batteryExemptionGranted
          : uiStrings.batteryExemptionKept,
      );
      if (granted) setExempt(true);
    } finally {
      setBusy(false);
    }
  }, [busy, requestExemption]);

  if (Platform.OS !== "android") return null;
  if (exempt === true) return null;
  const label = `${uiStrings.batteryExemptionTitle}. ${uiStrings.batteryExemptionBody}`;

  return (
    <View
      accessibilityLabel={label}
      style={[styles.card, { backgroundColor: t.colors.surface, borderColor: t.colors.line }]}>
      <Text style={t.text.bodyStrong}>{uiStrings.batteryExemptionTitle}</Text>
      <Text style={[t.text.caption, { color: t.colors.inkMuted }]}>
        {uiStrings.batteryExemptionBody}
      </Text>
      <Pressable
        onPress={() => void onRequest()}
        accessibilityRole="button"
        accessibilityLabel={uiStrings.batteryExemptionAction}
        accessibilityHint={uiStrings.batteryExemptionBody}
        style={[styles.action, { backgroundColor: t.colors.surfaceSunken, minHeight: 48 }]}>
        <Text style={t.text.label}>{uiStrings.batteryExemptionAction}</Text>
      </Pressable>
      {feedback ? (
        <Text
          accessibilityLiveRegion="polite"
          style={[t.text.caption, { color: t.colors.inkMuted }]}>
          {feedback}
        </Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: 16, padding: 16, gap: 8 },
  action: {
    paddingHorizontal: 16,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
  },
});

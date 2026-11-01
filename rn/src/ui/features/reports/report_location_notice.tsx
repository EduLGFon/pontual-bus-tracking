// One-time location notice before the OS permission prompt.
// Port of app/lib/ui/features/reports/report_location_notice.dart.
import React, { useEffect, useState } from "react";
import { Text, View, StyleSheet } from "react-native";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton, SecondaryButton } from "../../design/components/buttons";
import { PontualSheet } from "../../design/components/pontual_sheet";
import * as storage from "../../../data/prefs/storage";

const noticeKey = "ui_report_location_notice_v1";

export function useReportLocationNotice(): { shouldShow: () => Promise<boolean>; markShown: () => void } {
  return {
    shouldShow: async () => {
      try {
        return (await storage.getItem(noticeKey)) !== "1";
      } catch {
        return true;
      }
    },
    markShown: () => {
      storage.setItem(noticeKey, "1").catch(() => {});
    },
  };
}

export function ReportLocationNotice({ onAccept, onDecline }: { onAccept: () => void; onDecline: () => void }) {
  const t = useTheme();
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    let live = true;
    storage
      .getItem(noticeKey)
      .then((v) => {
        if (live && v !== "1") setVisible(true);
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);
  if (!visible) return null;
  const dismiss = (fn: () => void) => () => {
    setVisible(false);
    storage.setItem(noticeKey, "1").catch(() => {});
    fn();
  };
  return (
    <PontualSheet title="Sua localização">
      <View style={styles.body}>
        <Text style={t.text.body}>
          Para sinalizar espera ou acesso bloqueado, lemos sua posição uma vez e enviamos só uma área
          aproximada de 150 m. A posição exata nunca sai do aparelho.
        </Text>
        <View style={styles.actions}>
          <PrimaryButton label="Continuar" onPress={dismiss(onAccept)} />
          <SecondaryButton label="Agora não" onPress={dismiss(onDecline)} />
        </View>
      </View>
    </PontualSheet>
  );
}

const styles = StyleSheet.create({ body: { gap: 16 }, actions: { gap: 8 } });

// Trip screen. Port of app/lib/ui/features/trip/trip_screen.dart.
// No map, no animations: hero, health at a glance, big way out.
// PRIVACY: shows the vehicle, never the rider. Elapsed ticker pauses when
// the app is backgrounded (the share itself continues).
import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Modal, ScrollView, Text, View, StyleSheet } from "react-native";
import { useRouter } from "expo-router";
import { useTheme } from "../../design/theme/context";
import { PrimaryButton, SecondaryButton } from "../../design/components/buttons";
import { Banner } from "../../design/components/banner";
import { lineVmOf } from "../../adapters/lines_adapter";
import { useStaticStore, useTripStore } from "../../../stores";
import { stopSharing } from "../../../features/trip/tripService";
import { uiStrings } from "../../strings/uiStrings";
import { TripHero } from "./trip_hero";
import { TripStatus } from "./trip_status";
import { TripEndCard } from "./trip_end_card";
import { LineChooserSheet } from "./line_chooser_sheet";
import { ConsentBody, PermissionPromptBody } from "./permission_sheets";
import { acceptConsent, finishShare, needsConsent, type ShareError } from "./trip_flow";

type Step = "choose" | "consent" | "permission" | "starting" | "error";

/** Elapsed ticker. Mounts fresh at 0 each time sharing starts; pauses with the app. */
function ElapsedHero({ lineLabel }: { lineLabel: string }) {
  const [elapsedS, setElapsedS] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setElapsedS((s) => s + 5), 5000);
    return () => clearInterval(id);
  }, []);
  return <TripHero elapsedS={elapsedS} lineLabel={lineLabel} />;
}

export function TripScreen({ initialLineKey }: { initialLineKey?: string }) {
  const t = useTheme();
  const router = useRouter();
  const phase = useTripStore((s) => s.phase);
  const trip = useTripStore((s) => s.trip);
  const lines = useStaticStore((s) => s.lines);
  const [step, setStep] = useState<Step | null>(initialLineKey ? null : "choose");
  const [lineKey, setLineKey] = useState<string | null>(initialLineKey ?? null);
  const [error, setError] = useState<string | null>(null);
  const [ended, setEnded] = useState(false);
  const [endReason, setEndReason] = useState<string | null>(null);

  const sharing = phase === "sharing" || phase === "starting";

  const vms = useMemo(() => lines.filter((l) => l.is_active && l.pilot).map((l) => lineVmOf(l, 0)), [lines]);
  const lineLabel = useMemo(() => {
    const id = trip?.lineId;
    if (id == null) return lineKey ?? "";
    const found = lines.find((l) => l.id === id);
    return found ? `${found.short} ${found.name}` : (lineKey ?? "");
  }, [trip, lines, lineKey]);

  const beginConsent = useCallback(async () => {
    setError(null);
    if (await needsConsent()) setStep("consent");
    else setStep("permission");
  }, []);

  const beginForLine = useCallback(
    (key: string) => {
      setLineKey(key);
      setStep(null);
      void beginConsent();
    },
    [beginConsent],
  );

  const runStart = useCallback(
    async (key: string) => {
      const numeric = lines.find((l) => l.code === key)?.id;
      if (numeric == null) {
        setError(uiStrings.genericError);
        setStep("error");
        return;
      }
      setStep("starting");
      const err: ShareError | null = await finishShare(numeric);
      if (err) {
        const { shareErrorMessage } = await import("./trip_flow");
        setError(shareErrorMessage(err));
        setStep("error");
        return;
      }
      setStep(null);
      setEnded(false);
    },
    [lines],
  );

  async function onEnd() {
    try {
      await stopSharing();
    } finally {
      setEnded(true);
      setEndReason(null);
      setLineKey(null);
    }
  }

  if (ended && !sharing) {
    return (
      <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
        <TripEndCard reason={endReason} onBack={() => router.replace("/")} />
      </View>
    );
  }

  return (
    <View style={[styles.root, { backgroundColor: t.colors.bg }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={t.text.display} accessibilityRole="header">
          {uiStrings.tripTitle}
        </Text>
        {sharing && trip ? (
          <>
            <View style={{ marginTop: 16 }}>
              <ElapsedHero lineLabel={lineLabel} />
            </View>
            <View style={{ marginTop: 12 }}>
              <TripStatus connected={phase === "sharing"} gpsGood={phase === "sharing"} role={trip.role} />
            </View>
            <View style={{ marginTop: 16 }}>
              <PrimaryButton label={uiStrings.endTrip} onPress={() => void onEnd()} />
            </View>
            <Text style={[t.text.caption, { color: t.colors.inkMuted, marginTop: 12 }]}>
              {uiStrings.tripStopCaption}
            </Text>
          </>
        ) : (
          <>
            <Text style={[t.text.body, { color: t.colors.inkMuted, marginTop: 8 }]}>{uiStrings.tripHero}</Text>
            {error ? (
              <View style={{ marginTop: 12 }}>
                <Banner text={error} />
              </View>
            ) : null}
            <View style={{ marginTop: 16 }}>
              <PrimaryButton
                label={lineKey ? `${uiStrings.dockIdle} · ${lineKey}` : uiStrings.chooseLineTitle}
                onPress={() => {
                  if (lineKey) void runStart(lineKey);
                  else setStep("choose");
                }}
              />
            </View>
            <View style={{ marginTop: 8 }}>
              <SecondaryButton label={uiStrings.back} onPress={() => router.back()} />
            </View>
          </>
        )}
      </ScrollView>

      <Modal visible={step === "choose"} animationType="slide" onRequestClose={() => setStep(null)}>
        <View style={[styles.modal, { backgroundColor: t.colors.bg }]}>
          <LineChooserSheet
            lines={vms}
            onChoose={(l) => {
              setStep(null);
              beginForLine(l.key);
            }}
          />
          <SecondaryButton label={uiStrings.cancel} onPress={() => setStep(null)} />
        </View>
      </Modal>
      <Modal visible={step === "consent"} animationType="slide" onRequestClose={() => setStep(null)}>
        <View style={[styles.modal, { backgroundColor: t.colors.bg }]}>
          <ConsentBody
            onAccept={() => {
              void acceptConsent().then(() => setStep("permission"));
            }}
            onDecline={() => setStep(null)}
          />
        </View>
      </Modal>
      <Modal visible={step === "permission"} animationType="slide" onRequestClose={() => setStep(null)}>
        <View style={[styles.modal, { backgroundColor: t.colors.bg }]}>
          <PermissionPromptBody
            onContinue={() => {
              if (lineKey) void runStart(lineKey);
              else setStep("choose");
            }}
            onCancel={() => setStep(null)}
          />
        </View>
      </Modal>
      <Modal visible={step === "starting"} transparent animationType="fade">
        <View style={styles.busy}>
          <Text style={t.text.bodyStrong}>{uiStrings.dockStarting}</Text>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  modal: { flex: 1, paddingTop: 48, paddingHorizontal: 16 },
  busy: { flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(0,0,0,0.3)" },
});

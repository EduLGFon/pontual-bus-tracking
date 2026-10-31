import { useState } from "react";
import { View, Text, Pressable, TextInput, Modal } from "react-native";
import { useRouter } from "expo-router";
import { startSharing, stopSharing, grantConsent } from "../features/trip/tripService";
import { useTripStore } from "../stores";
import { ensureForegroundPermission } from "../features/trip/permissionGateway";
import * as Location from "expo-location";

export default function TripScreen() {
  const router = useRouter();
  const phase = useTripStore((s) => s.phase);
  const trip = useTripStore((s) => s.trip);
  const [lineId, setLineId] = useState("60");
  const [msg, setMsg] = useState("");
  const [consentNeeded, setConsentNeeded] = useState(false);
  const [busy, setBusy] = useState(false);

  async function doStart() {
    setMsg("");
    setBusy(true);
    const ok = await ensureForegroundPermission();
    if (!ok) {
      setMsg("Permissão de localização negada");
      setBusy(false);
      return;
    }
    let lat = -18.7;
    let lng = -39.85;
    try {
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.High });
      lat = pos.coords.latitude;
      lng = pos.coords.longitude;
    } catch {}
    try {
      await startSharing(Number(lineId), {
        lat,
        lng,
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
      });
    } catch (e: any) {
      const m = String(e?.message ?? e);
      if (m.includes("consent_required")) setConsentNeeded(true);
      else setMsg(m);
    } finally {
      setBusy(false);
    }
  }

  async function onAcceptConsent() {
    setConsentNeeded(false);
    setBusy(true);
    try {
      await grantConsent();
      await doStart();
    } catch (e: any) {
      setMsg(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={{ flex: 1, padding: 16 }}>
      <Text style={{ fontSize: 18, fontWeight: "bold" }}>Compartilhar viagem</Text>
      <Text style={{ marginVertical: 8 }}>Fase: {phase}</Text>
      {trip && (
        <Text>
          Linha {trip.lineId} - {trip.role} - proximo em {trip.intervalS}s
        </Text>
      )}
      {phase === "idle" && (
        <>
          <TextInput
            placeholder="ID da linha"
            value={lineId}
            onChangeText={setLineId}
            style={{ borderWidth: 1, padding: 8, marginVertical: 4, borderRadius: 6 }}
          />
          <Pressable
            onPress={doStart}
            disabled={busy}
            style={{ marginTop: 8, padding: 12, backgroundColor: "#208AEF", borderRadius: 6, opacity: busy ? 0.6 : 1 }}
          >
            <Text style={{ color: "white", textAlign: "center" }}>
              {busy ? "Iniciando..." : "Iniciar"}
            </Text>
          </Pressable>
        </>
      )}
      {phase === "sharing" && (
        <Pressable
          onPress={() => stopSharing()}
          style={{ marginTop: 8, padding: 12, backgroundColor: "#d33", borderRadius: 6 }}
        >
          <Text style={{ color: "white", textAlign: "center" }}>Encerrar</Text>
        </Pressable>
      )}
      {msg ? <Text style={{ color: "red", marginTop: 8 }}>{msg}</Text> : null}
      <Pressable onPress={() => router.back()} style={{ marginTop: 16 }}>
        <Text style={{ color: "#208AEF" }}>Voltar</Text>
      </Pressable>

      <Modal visible={consentNeeded} transparent animationType="fade">
        <View style={{ flex: 1, justifyContent: "center", alignItems: "center", backgroundColor: "rgba(0,0,0,0.5)" }}>
          <View style={{ backgroundColor: "white", padding: 20, borderRadius: 8, width: "80%" }}>
            <Text style={{ fontSize: 16, fontWeight: "bold", marginBottom: 8 }}>Consentimento</Text>
            <Text style={{ marginBottom: 12 }}>
              Para compartilhar a viagem, precisamos do seu consentimento para coletar localização durante a viagem.
            </Text>
            <Pressable
              onPress={onAcceptConsent}
              style={{ padding: 10, backgroundColor: "#208AEF", borderRadius: 6 }}
            >
              <Text style={{ color: "white", textAlign: "center" }}>Aceitar</Text>
            </Pressable>
            <Pressable
              onPress={() => setConsentNeeded(false)}
              style={{ marginTop: 8, padding: 10 }}
            >
              <Text style={{ textAlign: "center" }}>Cancelar</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
}
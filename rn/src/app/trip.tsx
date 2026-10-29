import { useState } from "react";
import { View, Text, Pressable, TextInput } from "react-native";
import { useRouter } from "expo-router";
import { startSharing, stopSharing } from "../features/trip/tripService";
import { useTripStore } from "../stores";
import { ensureForegroundPermission } from "../features/trip/permissionGateway";

export default function TripScreen() {
  const router = useRouter();
  const phase = useTripStore((s) => s.phase);
  const trip = useTripStore((s) => s.trip);
  const [lineId, setLineId] = useState("60");
  const [lat, setLat] = useState("-18.7");
  const [lng, setLng] = useState("-39.85");
  const [msg, setMsg] = useState("");

  async function onStart() {
    setMsg("");
    const ok = await ensureForegroundPermission();
    if (!ok) {
      setMsg("Permissão de localização negada");
      return;
    }
    try {
      await startSharing(Number(lineId), {
        lat: Number(lat),
        lng: Number(lng),
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
      });
    } catch (e: any) {
      setMsg(String(e?.message ?? e));
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
          <TextInput
            placeholder="lat"
            value={lat}
            onChangeText={setLat}
            style={{ borderWidth: 1, padding: 8, marginVertical: 4, borderRadius: 6 }}
          />
          <TextInput
            placeholder="lng"
            value={lng}
            onChangeText={setLng}
            style={{ borderWidth: 1, padding: 8, marginVertical: 4, borderRadius: 6 }}
          />
          <Pressable
            onPress={onStart}
            style={{ marginTop: 8, padding: 12, backgroundColor: "#208AEF", borderRadius: 6 }}
          >
            <Text style={{ color: "white", textAlign: "center" }}>Iniciar</Text>
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
    </View>
  );
}

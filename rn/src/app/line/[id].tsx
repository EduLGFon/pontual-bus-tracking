import { useEffect, useState } from "react";
import { View, Text, ScrollView, Pressable } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { staticData } from "../../data/static/staticData";
import { busApi } from "../../data/api/busApi";
import { Map } from "../../ui/components/Map";
import type { StaticLine } from "../../data/static/staticData";
import { useStaticStore } from "../../stores";

export default function LineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const lineId = Number(id);
  const router = useRouter();
  const lines = useStaticStore((s) => s.lines);
  const [line, setLine] = useState<StaticLine | null>(null);
  const [vehicles, setVehicles] = useState<{ id: number; lat: number; lng: number }[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const l = lines.find((x) => x.id === lineId) ?? null;
    setLine(l);
    if (!l) {
      (async () => {
        const ls = await staticData.currentLines();
        setLine(ls.find((x) => x.id === lineId) ?? null);
      })();
    }
  }, [lines, lineId]);

  useEffect(() => {
    let mounted = true;
    async function load() {
      setLoading(true);
      const r = await busApi.getVehicles(lineId);
      if (mounted && r.ok) {
        const snap = r.value as any;
        const vs = (snap.v ?? []).map((row: any[]) => ({
          id: row[0],
          lat: row[1],
          lng: row[2],
        }));
        setVehicles(vs);
      }
      setLoading(false);
    }
    load();
    const t = setInterval(load, 5000);
    return () => {
      mounted = false;
      clearInterval(t);
    };
  }, [lineId]);

  if (!line) {
    return (
      <View style={{ flex: 1, padding: 16 }}>
        <Text>Carregando...</Text>
      </View>
    );
  }

  const center = vehicles[0]
    ? { lat: vehicles[0].lat, lng: vehicles[0].lng }
    : { lat: -18.7, lng: -39.85 };

  return (
    <View style={{ flex: 1 }}>
      <View style={{ height: 260 }}>
        <Map
          styleUrl={
            (line as any)?.tile_url ||
            "https://demotiles.maplibre.org/style.json"
          }
          initialCenter={center}
          initialZoom={12}
          markers={vehicles.map((v) => ({ id: String(v.id), lat: v.lat, lng: v.lng }))}
        />
      </View>
      <ScrollView style={{ flex: 1, padding: 12 }}>
        <Text style={{ fontSize: 18, fontWeight: "bold" }}>
          {line.short} {line.name}
        </Text>
        <Text style={{ color: "#666" }}>
          {loading ? "Atualizando..." : `${vehicles.length} veículo(s)`}
        </Text>
        <Pressable
          onPress={() => router.push("/trip")}
          style={{ marginTop: 12, padding: 10, backgroundColor: "#208AEF", borderRadius: 6 }}
        >
          <Text style={{ color: "white", textAlign: "center" }}>
            Compartilhar viagem nesta linha
          </Text>
        </Pressable>
        <Text style={{ marginTop: 16, fontWeight: "bold" }}>Horários</Text>
        {line.schedules.map((s, i) => (
          <View key={i} style={{ marginTop: 6 }}>
            <Text style={{ fontWeight: "600" }}>
              {s.day_type} - {s.origin}
            </Text>
            <Text style={{ fontSize: 12 }}>{s.times.join(", ")}</Text>
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

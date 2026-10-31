import { useEffect, useState } from "react";
import { View, Text, ScrollView, Pressable } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { staticData } from "../../data/static/staticData";
import { busApi } from "../../data/api/busApi";
import { Map } from "../../ui/components/Map";
import type { StaticLine } from "../../data/static/staticData";
import { useStaticStore } from "../../stores";
import * as reportActions from "../../features/reports/reportActions";
import * as tokenStore from "../../data/prefs/tokenStore";
import { learningRepo } from "../../data/learning/learningRepository";

export default function LineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const lineId = Number(id);
  const router = useRouter();
  const lines = useStaticStore((s) => s.lines);
  const [fetchedLine, setFetchedLine] = useState<StaticLine | null>(null);
  const [vehicles, setVehicles] = useState<{ id: number; lat: number; lng: number }[]>([]);
  const [loading, setLoading] = useState(false);
  const [arrivals, setArrivals] = useState<number[]>([]);
  const [reportMsg, setReportMsg] = useState("");
  const [learnedStops, setLearnedStops] = useState<any[]>([]);

  useEffect(() => {
    if (lines.some((x) => x.id === lineId)) return;
    let cancelled = false;
    (async () => {
      const ls = await staticData.currentLines();
      if (!cancelled) setFetchedLine(ls.find((x) => x.id === lineId) ?? null);
    })();
    return () => {
      cancelled = true;
    };
  }, [lines, lineId]);

  const line = lines.find((x) => x.id === lineId) ?? fetchedLine;

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
      const a = await busApi.getArrivals(lineId);
      if (mounted && a.ok) {
        setArrivals((a.value as any)?.passages ?? []);
      }
      const ls = await learningRepo.learnedStops(lineId);
      if (mounted && ls) {
        setLearnedStops((ls as any)?.stops ?? []);
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

  async function onReport(kind: string) {
    setReportMsg("");
    let t = await tokenStore.readToken();
    if (!t) {
      const r = await busApi.getOrCreateToken();
      if (!r.ok) {
        setReportMsg("Falha ao registrar dispositivo");
        return;
      }
      t = r.value;
    }
    const res = await reportActions.createReport(t, kind, lineId, -18.7, -39.85);
    if (res.ok) setReportMsg("Reporte enviado");
    else setReportMsg("Falha no reporte");
  }

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
          styleUrl="https://demotiles.maplibre.org/style.json"
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

        <Text style={{ marginTop: 12, fontWeight: "bold" }}>Próximas chegadas</Text>
        {arrivals.length === 0 ? (
          <Text style={{ fontSize: 12, color: "#666" }}>Sem dados</Text>
        ) : (
          arrivals.map((a, i) => (
            <Text key={i} style={{ fontSize: 12 }}>
              {a}s
            </Text>
          ))
        )}

        <Text style={{ marginTop: 12, fontWeight: "bold" }}>Reportar</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, marginTop: 6 }}>
          {["waiting", "full", "broken", "blocked"].map((k) => (
            <Pressable
              key={k}
              onPress={() => onReport(k)}
              style={{ padding: 8, backgroundColor: "#eee", borderRadius: 6 }}
            >
              <Text style={{ fontSize: 12 }}>{k}</Text>
            </Pressable>
          ))}
        </View>
        {reportMsg ? <Text style={{ marginTop: 6, color: "#666" }}>{reportMsg}</Text> : null}

        <Text style={{ marginTop: 12, fontWeight: "bold" }}>Paradas aprendidas</Text>
        {learnedStops.length === 0 ? (
          <Text style={{ fontSize: 12, color: "#666" }}>Sem dados</Text>
        ) : (
          learnedStops.slice(0, 5).map((s: any, i: number) => (
            <Text key={i} style={{ fontSize: 12 }}>
              {s.id} ({s.lat.toFixed(4)}, {s.lng.toFixed(4)})
            </Text>
          ))
        )}

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
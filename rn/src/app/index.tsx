import { useEffect, useState } from "react";
import { FlatList, Text, View, Pressable, TextInput } from "react-native";
import { useRouter } from "expo-router";
import { staticData } from "../data/static/staticData";
import { busApi } from "../data/api/busApi";
import { useStaticStore, useRemoteConfigStore } from "../stores";
import type { StaticLine } from "../data/static/staticData";

export default function HomeScreen() {
  const router = useRouter();
  const lines = useStaticStore((s) => s.lines);
  const setLines = useStaticStore((s) => s.setLines);
  const rc = useRemoteConfigStore((s) => s.config);
  const [q, setQ] = useState("");
  const [live, setLive] = useState<Record<number, number>>({});

  useEffect(() => {
    (async () => {
      const ls = await staticData.currentLines();
      setLines(ls);
      void staticData.refresh();
      const { remoteConfigRepo } = await import("../data/config/remoteConfig");
      const cfg = await remoteConfigRepo.current();
      useRemoteConfigStore.getState().setConfig(cfg);
      void remoteConfigRepo.refresh();
      const loadLive = async () => {
        const r = await busApi.getLive();
        if (r.ok) {
          const m: Record<number, number> = {};
          for (const row of r.value as any) {
            m[row[0]] = row[1];
          }
          setLive(m);
        }
      };
      void loadLive();
    })();
  }, [setLines]);

  useEffect(() => {
    const loadLive = async () => {
      const r = await busApi.getLive();
      if (r.ok) {
        const m: Record<number, number> = {};
        for (const row of r.value as any) m[row[0]] = row[1];
        setLive(m);
      }
    };
    void loadLive();
    const t = setInterval(loadLive, 10000);
    return () => clearInterval(t);
  }, []);

  const filtered = lines.filter((l) =>
    l.is_active && (q === "" || l.name.toLowerCase().includes(q.toLowerCase()) || l.short.includes(q)),
  );

  if (rc?.maintenance) {
    return (
      <View style={{ flex: 1, padding: 16, justifyContent: "center" }}>
        <Text style={{ fontSize: 18, textAlign: "center" }}>
          {rc.message_pt || "Manutenção em andamento."}
        </Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, padding: 12 }}>
      <TextInput
        placeholder="Buscar linha"
        value={q}
        onChangeText={setQ}
        style={{ borderWidth: 1, padding: 8, marginBottom: 8, borderRadius: 6 }}
      />
      <FlatList
        data={filtered}
        keyExtractor={(l) => String(l.id)}
        renderItem={({ item }: { item: StaticLine }) => (
          <Pressable
            onPress={() => router.push(`/line/${item.id}`)}
            style={{ padding: 12, borderBottomWidth: 1, borderColor: "#ddd" }}
          >
            <Text style={{ fontWeight: "bold" }}>
              {item.short} {item.name}
            </Text>
            <Text style={{ color: "#666", fontSize: 12 }}>
              {item.pilot ? "piloto" : "horários"}
              {live[item.id] ? ` • ${live[item.id]} ao vivo` : ""}
            </Text>
          </Pressable>
        )}
      />
    </View>
  );
}

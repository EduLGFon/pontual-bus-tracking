import { useEffect, useState } from "react";
import { FlatList, Text, View, Pressable, TextInput } from "react-native";
import { useRouter } from "expo-router";
import { staticData } from "../data/static/staticData";
import { useStaticStore } from "../stores";
import type { StaticLine } from "../data/static/staticData";

export default function HomeScreen() {
  const router = useRouter();
  const lines = useStaticStore((s) => s.lines);
  const setLines = useStaticStore((s) => s.setLines);
  const [q, setQ] = useState("");

  useEffect(() => {
    (async () => {
      const ls = await staticData.currentLines();
      setLines(ls);
      void staticData.refresh();
    })();
  }, [setLines]);

  const filtered = lines.filter((l) =>
    l.is_active && (q === "" || l.name.toLowerCase().includes(q.toLowerCase()) || l.short.includes(q)),
  );

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
            </Text>
          </Pressable>
        )}
      />
    </View>
  );
}

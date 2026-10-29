import { useState } from "react";
import { View, Text, Pressable } from "react-native";
import { useRouter } from "expo-router";
import { busApi } from "../data/api/busApi";
import * as tokenStore from "../data/prefs/tokenStore";
import { consentStore } from "../data/prefs/consentStore";

export default function SettingsScreen() {
  const router = useRouter();
  const [msg, setMsg] = useState("");
  async function onDelete() {
    const t = await tokenStore.readToken();
    if (!t) {
      setMsg("Sem token");
      return;
    }
    const r = await busApi.deleteMe(t);
    if (r.ok) {
      await tokenStore.clearToken();
      await consentStore.clear();
      setMsg("Dados apagados");
    } else setMsg("Falha");
  }
  return (
    <View style={{ flex: 1, padding: 16 }}>
      <Text style={{ fontSize: 18, fontWeight: "bold" }}>Configurações</Text>
      <Pressable
        onPress={onDelete}
        style={{ marginTop: 12, padding: 12, backgroundColor: "#d33", borderRadius: 6 }}
      >
        <Text style={{ color: "white", textAlign: "center" }}>Apagar meus dados</Text>
      </Pressable>
      <Pressable onPress={() => router.push("/privacy")} style={{ marginTop: 12 }}>
        <Text style={{ color: "#208AEF" }}>Política de Privacidade</Text>
      </Pressable>
      {msg ? <Text style={{ marginTop: 8 }}>{msg}</Text> : null}
    </View>
  );
}

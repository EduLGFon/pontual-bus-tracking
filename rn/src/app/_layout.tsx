// Root layout.
import { Stack } from "expo-router";
import { useEffect } from "react";
import { Platform } from "react-native";
import "../features/map/maplibreWorker";

export default function RootLayout() {
  useEffect(() => {
    // worker import side-effect only on web; guard
    if (Platform.OS !== "web") return;
  }, []);
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: "Pontual (RN)" }} />
      <Stack.Screen name="line/[id]" options={{ title: "Linha" }} />
      <Stack.Screen name="trip" options={{ title: "Compartilhar" }} />
      <Stack.Screen name="settings" options={{ title: "Configurações" }} />
      <Stack.Screen name="privacy" options={{ title: "Privacidade" }} />
    </Stack>
  );
}

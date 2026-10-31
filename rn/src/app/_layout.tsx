// Root layout: theme provider plus every route (PLAN.md S01-S15).
import { Stack } from "expo-router";
import { ThemeProvider } from "../ui/design/theme/context";

export default function RootLayout() {
  return (
    <ThemeProvider>
      <Stack>
        <Stack.Screen name="index" options={{ title: "pontual" }} />
        <Stack.Screen name="welcome" options={{ title: "Bem-vindo" }} />
        <Stack.Screen name="lines" options={{ title: "Linhas" }} />
        <Stack.Screen name="search" options={{ title: "Buscar" }} />
        <Stack.Screen name="line/[id]" options={{ title: "Linha" }} />
        <Stack.Screen name="trip" options={{ title: "Compartilhar" }} />
        <Stack.Screen name="settings" options={{ title: "Ajustes" }} />
        <Stack.Screen name="privacy" options={{ title: "Privacidade" }} />
        <Stack.Screen name="privacy/policy" options={{ title: "Política de Privacidade" }} />
        <Stack.Screen name="privacy/terms" options={{ title: "Termos de Uso" }} />
        <Stack.Screen name="about" options={{ title: "Sobre" }} />
        <Stack.Screen name="system/index" options={{ title: "Aviso" }} />
        <Stack.Screen name="system/[kind]" options={{ title: "Aviso" }} />
      </Stack>
    </ThemeProvider>
  );
}

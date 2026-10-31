// About screen. Port of app/lib/ui/features/settings/about_screen.dart.
// Independent, unofficial app: no operator or city affiliation.
import React from "react";
import { Linking, ScrollView, Text, StyleSheet, View } from "react-native";
import { useTheme } from "../../design/theme/context";
import { GhostLink } from "../../design/components/ghost_link";
import { uiStrings } from "../../strings/uiStrings";

export function AboutScreen() {
  const t = useTheme();
  return (
    <ScrollView style={[styles.root, { backgroundColor: t.colors.bg }]} contentContainerStyle={styles.content}>
      <Text style={t.text.display}>{uiStrings.wordmark}</Text>
      <Text style={[t.text.body, { marginTop: 12 }]}>
        App independente e não oficial. Não é da Viação São Gabriel nem da Prefeitura de São Mateus.
      </Text>
      <Text style={[t.text.headline, styles.h]} accessibilityRole="header">
        {uiStrings.sources}
      </Text>
      <Text style={[t.text.body, { color: t.colors.inkMuted }]}>
        Horários e linhas vêm dos arquivos estáticos do projeto. Posições ao vivo são compartilhadas por
        passageiros a bordo, de forma anônima.
      </Text>
      <View style={styles.links}>
        <GhostLink label={uiStrings.attribution} onPress={() => void Linking.openURL("https://www.openstreetmap.org/copyright")} />
      </View>
      <Text style={[t.text.headline, styles.h]} accessibilityRole="header">
        Código aberto
      </Text>
      <Text style={[t.text.body, { color: t.colors.inkMuted }]}>Licença e repositório no site do projeto.</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  h: { marginTop: 24 },
  links: { alignItems: "flex-start", marginTop: 8 },
});

import { View, Text, ScrollView } from "react-native";

export default function PrivacyScreen() {
  return (
    <ScrollView style={{ flex: 1, padding: 16 }}>
      <Text style={{ fontSize: 18, fontWeight: "bold" }}>Privacidade</Text>
      <Text style={{ marginTop: 8 }}>
        Este app coleta localização apenas durante viagens ativas. Dados são
        apagados ao fim da viagem. Veja a política completa no site.
      </Text>
    </ScrollView>
  );
}

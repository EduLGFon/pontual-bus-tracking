// Line route: /line/[id]?tab=agora|horarios (S04 Mapa, S05 Horários).
// Accepts the stable line code or the numeric id.
import { useLocalSearchParams } from "expo-router";
import { LineScreen } from "../../ui/features/line/line_screen";

export default function LineRoute() {
  const { id, tab } = useLocalSearchParams<{ id: string; tab?: string }>();
  const tabValue = Array.isArray(tab) ? tab[0] : tab;
  const key = Array.isArray(id) ? id[0] : id;
  return <LineScreen lineKey={key ?? ""} tab={tabValue} />;
}

// Trip route (S08 active, S09 ended). Optional ?line=<code> preselects.
import { useLocalSearchParams } from "expo-router";
import { TripScreen } from "../ui/features/trip/trip_screen";

export default function TripRoute() {
  const { line } = useLocalSearchParams<{ line?: string }>();
  const key = Array.isArray(line) ? line[0] : line;
  return <TripScreen initialLineKey={key} />;
}

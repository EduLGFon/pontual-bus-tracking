// System kind route: /system/maintenance, /system/update,
// /system/serverDown, /system/notFound. Optional ?message= override.
import { useLocalSearchParams } from "expo-router";
import { SystemScreen, systemKindOf } from "../../ui/features/system/system_screen";

export default function SystemKindRoute() {
  const { kind, message } = useLocalSearchParams<{ kind: string; message?: string }>();
  const raw = Array.isArray(kind) ? kind[0] : kind;
  const msg = Array.isArray(message) ? message[0] : message;
  return <SystemScreen kind={systemKindOf(raw)} message={msg} />;
}

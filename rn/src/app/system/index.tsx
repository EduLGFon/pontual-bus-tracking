// System route (S13). /system defaults to maintenance;
// /system/:kind selects update, serverDown or notFound.
import { SystemScreen } from "../../ui/features/system/system_screen";

export default function SystemIndexRoute() {
  return <SystemScreen kind="maintenance" />;
}

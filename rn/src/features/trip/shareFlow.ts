// Share-trip entry guards. Mirrors app/lib/features/trip/share_flow.dart.
// UI decisions live in src/ui/features/trip/trip_flow.ts; this module holds
// the headless rule: only pilot lines can share. Navigation and sheets are
// owned by the UI layer.
import type { StaticLine } from "../../data/static/staticData";

export function canShareLine(line: Pick<StaticLine, "pilot" | "is_active">): boolean {
  return line.pilot && line.is_active;
}

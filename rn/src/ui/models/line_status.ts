// Line status. Port of app/lib/ui/models/line_status.dart.
import { normalizeText } from "../util/search_index";

export type LineStatusKind =
  | "live" | "now" | "imminent" | "upcoming" | "tomorrow" | "noneToday" | "noTimetable";

export interface LineStatus {
  kind: LineStatusKind;
  time?: string | null;
  minutes?: number | null;
}

export const lineImminentThresholdMin = 10;

export function resolveLineStatus(params: {
  isLive: boolean;
  hasTimetable: boolean;
  next?: { isTomorrow: boolean; time: string } | null;
  nowMinutes: number;
}): LineStatus {
  if (params.isLive) return { kind: "live" };
  if (!params.hasTimetable) return { kind: "noTimetable" };
  if (!params.next) return { kind: "noneToday" };
  if (params.next.isTomorrow) return { kind: "tomorrow", time: params.next.time };
  const minutes = minutesUntil(params.next.time, params.nowMinutes);
  if (minutes <= 0) return { kind: "now", time: params.next.time };
  if (minutes < lineImminentThresholdMin) return { kind: "imminent", time: params.next.time, minutes };
  return { kind: "upcoming", time: params.next.time, minutes };
}

function minutesUntil(time: string, nowMinutes: number): number {
  const parts = time.split(":");
  const h = parseInt(parts[0] ?? "0", 10);
  const m = parseInt(parts[1] ?? "0", 10);
  return h * 60 + m - nowMinutes;
}

export function shouldShowTerminals(name: string, terminals: string[]): boolean {
  const title = normalizeText(name);
  if (!title) return terminals.length > 0;
  for (const terminal of terminals) {
    const norm = normalizeText(terminal);
    if (!norm) continue;
    if (!title.includes(norm)) return true;
  }
  return false;
}
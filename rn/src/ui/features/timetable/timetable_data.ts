// Timetable data helpers. Port of app/lib/ui/features/timetable/timetable_data.dart.
import type { StaticLine } from "../../../data/static/staticData";

export type DayType = "weekday" | "saturday" | "sunday";

export function dayTypeOf(date: Date): DayType {
  const d = date.getDay();
  if (d === 0) return "sunday";
  if (d === 6) return "saturday";
  return "weekday";
}

export function originsOf(line: StaticLine, day: DayType): string[] {
  const seen: string[] = [];
  for (const s of line.schedules) {
    if (s.day_type !== day) continue;
    if (!seen.includes(s.origin)) seen.push(s.origin);
  }
  return seen;
}

export function timesOf(line: StaticLine, day: DayType, origin: string | null): string[] {
  const rows = line.schedules.filter((s) => s.day_type === day && (origin == null || s.origin === origin));
  const all = rows.flatMap((r) => r.times);
  return [...new Set(all)].sort();
}

export function groupByHour(times: string[]): { hour: string; times: string[] }[] {
  const map = new Map<string, string[]>();
  for (const t of [...times].sort()) {
    const h = t.split(":")[0];
    const arr = map.get(h) ?? [];
    arr.push(t);
    map.set(h, arr);
  }
  return [...map.entries()].map(([hour, list]) => ({ hour, times: list }));
}

/** First time strictly after nowHHMM, or null. */
export function nextTime(times: string[], nowHHMM: string): string | null {
  for (const t of [...times].sort()) {
    if (t > nowHHMM) return t;
  }
  return null;
}

export function nowHHMM(now: Date): string {
  const h = String(now.getHours()).padStart(2, "0");
  const m = String(now.getMinutes()).padStart(2, "0");
  return `${h}:${m}`;
}

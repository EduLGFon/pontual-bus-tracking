// Pure helpers for the home screen. Port of app/lib/ui/features/home/home_logic.dart.
// No widgets here; safe for unit tests.
import type { StaticLine } from "../../../data/static/staticData";

export const leavingNowThresholdMin = 15;
export const imminentThresholdMin = 10;

export type ShortcutCardState = "upcoming" | "imminent" | "live" | "noneToday" | "noData";

export function greetingFor(hour: number): string {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 18) return "afternoon";
  return "evening";
}

export function dedupeSubtitleParts(subtitle: string): string[] {
  const out: string[] = [];
  for (const part of subtitle.split("·")) {
    const trimmed = part.trim();
    if (trimmed === "" || out.includes(trimmed)) continue;
    out.push(trimmed);
  }
  return out;
}

export function joinSubtitle(parts: string[]): string {
  const out: string[] = [];
  for (const part of parts) {
    for (const sub of part.split("·")) {
      const trimmed = sub.trim();
      if (trimmed === "" || out.includes(trimmed)) continue;
      out.push(trimmed);
    }
  }
  return out.join(" · ");
}

export function proximasSectionTitle(soonestAtMs: number | null, nowMs: number): "saindo" | "proximas" {
  if (soonestAtMs != null && soonestAtMs - nowMs <= leavingNowThresholdMin * 60 * 1000) return "saindo";
  return "proximas";
}

export function departureKey(lineKey: string, originLabel: string | null, atIso: string): string {
  return `time|${lineKey}|${originLabel ?? ""}|${atIso}`;
}

export function liveKey(lineKey: string, originLabel: string | null): string {
  return `live|${lineKey}|${originLabel ?? ""}`;
}

export function resolveShortcutState(opts: {
  isLive: boolean;
  hasNext: boolean;
  nextInS: number | null;
  hasTimetable: boolean;
}): ShortcutCardState {
  if (opts.isLive) return "live";
  if (!opts.hasNext || opts.nextInS == null) return opts.hasTimetable ? "noneToday" : "noData";
  return opts.nextInS < imminentThresholdMin * 60 ? "imminent" : "upcoming";
}

export function directionLabel(opts: { terminals: string[]; originLabel: string | null }): string | null {
  const origin = opts.originLabel?.trim() ?? "";
  if (origin !== "") {
    for (const terminal of opts.terminals) {
      const t = terminal.trim();
      if (t !== "" && t !== origin) return `sentido ${t}`;
    }
    return origin;
  }
  const known = opts.terminals.map((t) => t.trim()).filter((t) => t !== "");
  if (known.length === 0) return null;
  return known.join(" · ");
}

function dayTypeOf(date: Date): string {
  const d = date.getDay();
  if (d === 0) return "sunday";
  if (d === 6) return "saturday";
  return "weekday";
}

function firstTimeAfter(times: string[], afterMinutes: number | null): string | null {
  const sorted = [...times].sort();
  if (afterMinutes == null) return sorted[0] ?? null;
  for (const t of sorted) {
    const [h, m] = t.split(":").map(Number);
    if (h * 60 + m > afterMinutes) return t;
  }
  return null;
}

/** Next HH:mm departure today for a line, or null. Client-side from bundled timetables. */
export function nextDepartureToday(line: StaticLine, now: Date): { time: string; origin: string } | null {
  const day = dayTypeOf(now);
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const rows = line.schedules.filter((s) => s.day_type === day);
  const pool = rows.length > 0 ? rows : [];
  let best: { time: string; origin: string } | null = null;
  for (const row of pool) {
    const t = firstTimeAfter(row.times, nowMin);
    if (t != null && (best == null || t < best.time)) best = { time: t, origin: row.origin };
  }
  return best;
}

/** First departure time (HH:mm) for the day after now, or null. Powers the "Amanhã HH:mm" hint. */
export function firstDepartureTomorrow(line: StaticLine): string | null {
  const all = line.schedules.flatMap((s) => s.times);
  if (all.length === 0) return null;
  return [...all].sort()[0] ?? null;
}

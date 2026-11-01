// Pure schedule helpers. Mirrors app/lib/domain/schedule.dart.
export type DayType = "weekday" | "saturday" | "sundayHoliday";

export function dayTypeFor(local: Date): DayType {
  const wd = local.getDay(); // 0 Sun ... 6 Sat
  if (wd === 6) return "saturday";
  if (wd === 0) return "sundayHoliday";
  return "weekday";
}

export function saoMateusTime(instant: Date): Date {
  return new Date(instant.getTime() - 3 * 60 * 60 * 1000);
}

export function minutesOf(hhmm: string): number {
  const parts = hhmm.split(":");
  return Number(parts[0]) * 60 + Number(parts[1]);
}

export function nowMinutesOf(local: Date): number {
  return local.getHours() * 60 + local.getMinutes();
}

export function isSameMinute(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate() &&
    a.getHours() === b.getHours() &&
    a.getMinutes() === b.getMinutes()
  );
}

export function isPastMinute(at: Date, now: Date): boolean {
  const ta = new Date(at.getFullYear(), at.getMonth(), at.getDate(), at.getHours(), at.getMinutes()).getTime();
  const tn = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes()).getTime();
  return ta < tn;
}

export function nextDeparture(times: string[], nowMinutes: number): string | null {
  let best: string | null = null;
  let bestMinutes = 0;
  for (const t of times) {
    const m = minutesOf(t);
    if (m < nowMinutes) continue;
    if (best === null || m < bestMinutes) {
      best = t;
      bestMinutes = m;
    }
  }
  return best;
}

export interface NextDeparture {
  time: string;
  isTomorrow: boolean;
}

export function earliestTime(times: string[]): string | null {
  let best: string | null = null;
  let bestMinutes = 0;
  for (const t of times) {
    const m = minutesOf(t);
    if (best === null || m < bestMinutes) {
      best = t;
      bestMinutes = m;
    }
  }
  return best;
}

export function resolveNextDeparture(opts: {
  todayTimes: string[];
  tomorrowTimes: string[];
  nowMinutes: number;
}): NextDeparture | null {
  const today = nextDeparture(opts.todayTimes, opts.nowMinutes);
  if (today !== null) return { time: today, isTomorrow: false };
  const tomorrow = earliestTime(opts.tomorrowTimes);
  if (tomorrow !== null) return { time: tomorrow, isTomorrow: true };
  return null;
}

export function minutesUntil(hhmm: string, nowMinutes: number): number {
  return minutesOf(hhmm) - nowMinutes;
}

export function groupByHour(times: string[]): Record<string, string[]> {
  const groups: Record<string, string[]> = {};
  for (const t of times) {
    const hour = t.split(":")[0];
    if (!groups[hour]) groups[hour] = [];
    groups[hour].push(t);
  }
  return groups;
}

// Passenger reports ("sinalizações"). Ephemeral, anonymous, per line.
// No coordinates, no free text, no votes: a report is created, refreshed by
// the same device, or retracted. Counts are distinct reporters, not votes.
// PRIVACY: reports live in API memory only and expire with their TTL.
// See DECISIONS.md#D82/D83 and PLAN.md 6.6.
import type { ReportKind, ReportState } from "./types.ts";
import type { Store } from "./store.ts";

/** Runtime tunables for reports. Defaults mirror PLAN.md 6.3. */
export interface ReportsConfig {
  enabled: boolean;
  maxPerLine: number;
  maxTotal: number;
  ttlS: Record<ReportKind, number>;
  maxAgeS: Record<ReportKind, number>;
}

/** Default report tunables. */
export function defaultReportsConfig(): ReportsConfig {
  return {
    enabled: true,
    maxPerLine: 8,
    maxTotal: 2000,
    ttlS: { waiting: 600, full: 900, broken: 1800, blocked: 1800 },
    maxAgeS: { waiting: 1800, full: 2700, broken: 7200, blocked: 7200 },
  };
}

/** One report as exposed by the public snapshot. */
export interface ReportRow {
  kind: ReportKind;
  area: string | null;
  count: number;
  created_age_s: number;
  updated_age_s: number;
  expires_in_s: number;
}

export type ReportResult =
  | { ok: true; created: boolean; changed: boolean }
  | { ok: false; code: "quota" | "disabled" };

// Public counts are capped like the vehicle member count: enough to show
// "5+ people", never an exact crowd size.
const MAX_PUBLIC_REPORTERS = 5;
const KIND_ORDER: Record<ReportKind, number> = {
  blocked: 0,
  broken: 1,
  full: 2,
  waiting: 3,
};

/**
 * True when the target does not match the kind. Waiting and blocked are
 * area-level; broken and full are line-level. A client-supplied vehicle id
 * is never part of the target.
 */
export function targetMismatch(
  kind: ReportKind,
  areaId: string | null,
): boolean {
  const needsArea = kind === "waiting" || kind === "blocked";
  if (needsArea) return areaId === null;
  return areaId !== null;
}

/** Stable in-memory key inside one line. */
export function reportKey(kind: ReportKind, areaId: string | null): string {
  return `${kind}:${areaId ?? "-"}`;
}

/** Active report count, used for the global cap. */
export function activeReportCount(store: Store): number {
  let total = 0;
  for (const line of store.reports.values()) total += line.size;
  return total;
}

/**
 * Create a report, add the device as a reporter, or refresh its freshness.
 * A repeated report from the same device never increases the count.
 */
export function applyReport(
  store: Store,
  lineId: number,
  kind: ReportKind,
  areaId: string | null,
  deviceId: string,
  nowMs: number,
  cfg: ReportsConfig,
): ReportResult {
  if (!cfg.enabled) return { ok: false, code: "disabled" };
  let line = store.reports.get(lineId);
  if (!line) {
    line = new Map<string, ReportState>();
    store.reports.set(lineId, line);
  }
  const key = reportKey(kind, areaId);
  const current = line.get(key);
  if (current && nowMs < current.expiresAtMs) {
    current.reporters.add(deviceId);
    current.updatedAtMs = nowMs;
    current.expiresAtMs = Math.min(
      current.createdAtMs + cfg.maxAgeS[kind] * 1000,
      nowMs + cfg.ttlS[kind] * 1000,
    );
    return { ok: true, created: false, changed: true };
  }
  if (current) line.delete(key);
  if (line.size >= cfg.maxPerLine) return { ok: false, code: "quota" };
  if (activeReportCount(store) >= cfg.maxTotal) {
    return { ok: false, code: "quota" };
  }
  const state: ReportState = {
    kind,
    lineId,
    areaId,
    createdAtMs: nowMs,
    updatedAtMs: nowMs,
    expiresAtMs: Math.min(
      nowMs + cfg.ttlS[kind] * 1000,
      nowMs + cfg.maxAgeS[kind] * 1000,
    ),
    reporters: new Set<string>([deviceId]),
  };
  line.set(key, state);
  return { ok: true, created: true, changed: true };
}

/**
 * Remove this device's contribution. The report disappears when no device
 * is left. Missing reports are idempotent successes.
 */
export function retractReport(
  store: Store,
  lineId: number,
  kind: ReportKind,
  areaId: string | null,
  deviceId: string,
): { changed: boolean; removed: boolean } {
  const line = store.reports.get(lineId);
  if (!line) return { changed: false, removed: false };
  const key = reportKey(kind, areaId);
  const current = line.get(key);
  if (!current) return { changed: false, removed: false };
  const had = current.reporters.delete(deviceId);
  if (!had) return { changed: false, removed: false };
  if (current.reporters.size === 0) {
    line.delete(key);
    if (line.size === 0) store.reports.delete(lineId);
    return { changed: true, removed: true };
  }
  return { changed: true, removed: false };
}

/** Drop expired reports. Returns the lines whose snapshot changed. */
export function pruneReports(store: Store, nowMs: number): number[] {
  const changed = new Set<number>();
  for (const [lineId, line] of store.reports) {
    for (const [key, report] of line) {
      if (nowMs >= report.expiresAtMs) {
        line.delete(key);
        changed.add(lineId);
      }
    }
    if (line.size === 0) store.reports.delete(lineId);
  }
  return [...changed];
}

/**
 * Remove every contribution from [deviceId]. Used by DELETE /v1/me.
 * Returns the lines whose snapshot changed.
 */
export function removeDeviceFromReports(
  store: Store,
  deviceId: string,
): number[] {
  const changed = new Set<number>();
  for (const [lineId, line] of store.reports) {
    for (const [key, report] of line) {
      if (!report.reporters.delete(deviceId)) continue;
      if (report.reporters.size === 0) line.delete(key);
      changed.add(lineId);
    }
    if (line.size === 0) store.reports.delete(lineId);
  }
  return [...changed];
}

/** Public rows for one line, expired reports omitted. */
export function reportRows(
  store: Store,
  lineId: number,
  nowMs: number,
): ReportRow[] {
  const line = store.reports.get(lineId);
  if (!line) return [];
  const out: ReportRow[] = [];
  for (const report of line.values()) {
    if (nowMs >= report.expiresAtMs) continue;
    out.push({
      kind: report.kind,
      area: report.areaId,
      count: Math.min(MAX_PUBLIC_REPORTERS, report.reporters.size),
      created_age_s: Math.max(
        0,
        Math.floor((nowMs - report.createdAtMs) / 1000),
      ),
      updated_age_s: Math.max(
        0,
        Math.floor((nowMs - report.updatedAtMs) / 1000),
      ),
      expires_in_s: Math.max(
        0,
        Math.floor((report.expiresAtMs - nowMs) / 1000),
      ),
    });
  }
  out.sort((a, b) => {
    const byKind = KIND_ORDER[a.kind] - KIND_ORDER[b.kind];
    if (byKind !== 0) return byKind;
    const byArea = (a.area ?? "").localeCompare(b.area ?? "");
    if (byArea !== 0) return byArea;
    return a.updated_age_s - b.updated_age_s;
  });
  return out;
}

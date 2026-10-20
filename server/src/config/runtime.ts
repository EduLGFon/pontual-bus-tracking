// Runtime config loader. Defaults compiled in; app_config rows override.
// Reloaded every 30 s by the background job (T11). Time is a parameter so
// tests use a fake clock. See PLAN.md 6.3.
import type { Sql } from "../db/client.ts";
import { defaultReportsConfig, type ReportsConfig } from "../domain/reports.ts";

export interface RuntimeConfig {
  serviceEnabled: boolean;
  consentVersion: number;
  maxActiveTrips: number;
  reports: ReportsConfig;
}

export function defaultRuntimeConfig(): RuntimeConfig {
  return {
    serviceEnabled: true,
    consentVersion: 1,
    maxActiveTrips: 300,
    reports: defaultReportsConfig(),
  };
}

function positiveInt(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const n = Math.trunc(value);
  return n > 0 ? n : null;
}

/** Load overrides from app_config. Unknown keys are ignored. */
export async function loadRuntimeConfig(sql: Sql): Promise<RuntimeConfig> {
  const cfg = defaultRuntimeConfig();
  const rows = await sql`select key, value from app_config`;
  for (const row of rows as unknown as { key: string; value: unknown }[]) {
    if (row.key === "service_enabled" && typeof row.value === "boolean") {
      cfg.serviceEnabled = row.value;
    } else if (row.key === "consent_version" && typeof row.value === "number") {
      cfg.consentVersion = Math.trunc(row.value);
    } else if (
      row.key === "max_active_trips" && typeof row.value === "number"
    ) {
      cfg.maxActiveTrips = Math.trunc(row.value);
    } else if (
      row.key === "reports_enabled" && typeof row.value === "boolean"
    ) {
      cfg.reports.enabled = row.value;
    } else if (row.key === "reports_max_per_line") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxPerLine = n;
    } else if (row.key === "reports_max_total") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxTotal = n;
    } else if (row.key === "reports_ttl_waiting_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.ttlS.waiting = n;
    } else if (row.key === "reports_ttl_full_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.ttlS.full = n;
    } else if (row.key === "reports_ttl_broken_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.ttlS.broken = n;
    } else if (row.key === "reports_ttl_blocked_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.ttlS.blocked = n;
    } else if (row.key === "reports_max_age_waiting_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxAgeS.waiting = n;
    } else if (row.key === "reports_max_age_full_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxAgeS.full = n;
    } else if (row.key === "reports_max_age_broken_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxAgeS.broken = n;
    } else if (row.key === "reports_max_age_blocked_s") {
      const n = positiveInt(row.value);
      if (n !== null) cfg.reports.maxAgeS.blocked = n;
    }
  }
  return cfg;
}

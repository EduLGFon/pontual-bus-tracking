import type { Sql } from "../db/client.ts";
import { defaultLearningConfig, type LearningConfig } from "./types.ts";

function num(v: unknown, fallback: number): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}
function bool(v: unknown, fallback: boolean): boolean {
  return typeof v === "boolean" ? v : fallback;
}

export async function loadLearningConfig(sql: Sql): Promise<LearningConfig> {
  const cfg = defaultLearningConfig();
  try {
    const rows = await sql`select key, value from app_config`;
    for (const row of rows as unknown as { key: string; value: unknown }[]) {
      switch (row.key) {
        case "learning_enabled":
          cfg.enabled = bool(row.value, cfg.enabled);
          break;
        case "learning_min_consent_version":
          cfg.minConsentVersion = Math.trunc(
            num(row.value, cfg.minConsentVersion),
          );
          break;
        case "learning_min_route_trips":
          cfg.minRouteTrips = Math.trunc(num(row.value, cfg.minRouteTrips));
          break;
        case "learning_min_stop_passes":
          cfg.minStopPasses = Math.trunc(num(row.value, cfg.minStopPasses));
          break;
        case "learning_k_min":
          cfg.kMin = Math.trunc(num(row.value, cfg.kMin));
          break;
        case "learning_trim_ends_s":
          cfg.trimEndsS = Math.trunc(num(row.value, cfg.trimEndsS));
          break;
        case "learning_flush_interval_s":
          cfg.flushIntervalS = Math.trunc(num(row.value, cfg.flushIntervalS));
          break;
        case "learning_cache_ttl_s":
          cfg.cacheTtlS = Math.trunc(num(row.value, cfg.cacheTtlS));
          break;
        case "learning_route_bins":
          cfg.routeBins = Math.trunc(num(row.value, cfg.routeBins));
          break;
        case "learning_stop_cluster_radius_m":
          cfg.stopClusterRadiusM = num(row.value, cfg.stopClusterRadiusM);
          break;
        case "learning_stop_speed_mps":
          cfg.stopSpeedMps = num(row.value, cfg.stopSpeedMps);
          break;
        case "learning_min_dwell_s":
          cfg.minDwellS = Math.trunc(num(row.value, cfg.minDwellS));
          break;
        case "learning_headway_horizon_s":
          cfg.headwayHorizonS = Math.trunc(num(row.value, cfg.headwayHorizonS));
          break;
        case "learning_default_speed_mps":
          cfg.defaultSpeedMps = num(row.value, cfg.defaultSpeedMps);
          break;
        case "learning_default_dwell_s":
          cfg.defaultDwellS = Math.trunc(num(row.value, cfg.defaultDwellS));
          break;
      }
    }
  } catch {
    // DB down: keep defaults.
  }
  return cfg;
}

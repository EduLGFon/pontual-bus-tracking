// Background jobs. Tick, config refresh, device purge, db health.
// Overlap guard on the tick; every timer is registered for graceful
// shutdown. Time is a parameter where tests need a fake clock.
// See PLAN.md 6.10.
import type { Sql } from "../db/client.ts";
import { purgeExpiredDevices } from "../db/devices.ts";
import { purgeOldDiagnostics } from "../db/diagnostics.ts";
import { loadRuntimeConfig, type RuntimeConfig } from "../config/runtime.ts";
import { tick } from "../domain/tick.ts";
import type { Store } from "../state/store.ts";
import type { EngineConfig, EngineEvent } from "../domain/types.ts";

export interface JobsDeps {
  sql: Sql;
  store: Store;
  engine: EngineConfig;
  events: EngineEvent[];
  tickPeriodMs: number;
  configRefreshMs: number;
  purgeAtMs: (nowMs: number) => number;
  dbHealthMs: number;
  onTick: (changedLines: number[]) => void;
  onConfig: (cfg: RuntimeConfig) => void;
  onTickEvents?: (events: EngineEvent[]) => void;
}

export interface Jobs {
  stop(): void;
}

/** Run one tick with overlap guard. Returns true when the tick ran. */
export function runTickGuarded(
  guard: { running: boolean },
  store: Store,
  events: EngineEvent[],
  nowMs: number,
  engine: EngineConfig,
  onEvents?: (events: EngineEvent[]) => void,
): { ran: boolean; changedLines: number[] } {
  if (guard.running) return { ran: false, changedLines: [] };
  guard.running = true;
  try {
    const out = tick(store, events, nowMs, engine);
    // Hand events to consumers before draining.
    if (onEvents && events.length > 0) onEvents([...events]);
    // Drain so ended trips do not accumulate.
    events.length = 0;
    return { ran: true, changedLines: out.changedLines };
  } finally {
    guard.running = false;
  }
}

/** Delete devices past expiry. Returns the purged count. */
export async function runPurge(sql: Sql, now: Date): Promise<number> {
  return await purgeExpiredDevices(sql, now);
}

/** Delete diagnostics older than 14 days. */
export async function runPurgeDiagnostics(
  sql: Sql,
  now: Date,
): Promise<number> {
  const cutoff = new Date(now.getTime() - 14 * 86400 * 1000);
  return await purgeOldDiagnostics(sql, cutoff);
}

/**
 * Retention cleanup for learning aggregates (F6). Histograms are cumulative
 * and carry no per-trip timestamps, so retention follows the stop lifecycle:
 * a stop with no pass for 90 days is deactivated, and an inactive stop is
 * deleted after another 90 days. Bins and derived stats cascade with it.
 * Route cells and edges are bounded by the fixed grid and line/direction
 * count; they are kept because the published route rebuilds from them.
 * See DECISIONS.md#D109.
 */
export async function runPurgeLearning(sql: Sql, now: Date): Promise<void> {
  const cutoff90 = new Date(now.getTime() - 90 * 86400 * 1000);
  const cutoff180 = new Date(now.getTime() - 180 * 86400 * 1000);
  const cutoff30 = new Date(now.getTime() - 30 * 86400 * 1000);
  await sql`update learned_stops set active = false where active = true and last_seen_at < ${cutoff90}`;
  await sql`delete from learned_stops where active = false and last_seen_at < ${cutoff180}`;
  await sql`delete from learned_routes where status = 'retired' and retired_at < ${cutoff30}`;
}

/** Reload runtime config from app_config. */
export async function runConfigRefresh(sql: Sql): Promise<RuntimeConfig> {
  return await loadRuntimeConfig(sql);
}

/** Cheap db health probe. True when the database answers. */
export async function runDbHealth(sql: Sql): Promise<boolean> {
  try {
    await sql`select 1 as one`;
    return true;
  } catch {
    return false;
  }
}

/** Start all background jobs. Call stop() on shutdown. */
export function startJobs(deps: JobsDeps): Jobs {
  const guard = { running: false };
  const timers: ReturnType<typeof setInterval>[] = [];

  timers.push(
    setInterval(() => {
      const out = runTickGuarded(
        guard,
        deps.store,
        deps.events,
        Date.now(),
        deps.engine,
        deps.onTickEvents,
      );
      if (out.ran && out.changedLines.length > 0) deps.onTick(out.changedLines);
    }, deps.tickPeriodMs),
  );
  timers.push(
    setInterval(async () => {
      // Never let a failing refresh kill the process: reads stay up
      // while the database is down. See DECISIONS.md T34-fix.
      try {
        deps.onConfig(await runConfigRefresh(deps.sql));
      } catch (e) {
        console.log(
          JSON.stringify({
            level: "error",
            msg: "config refresh failed",
            err: String(e),
          }),
        );
      }
    }, deps.configRefreshMs),
  );
  const nowMs = Date.now();
  const purgeDelay = Math.max(0, deps.purgeAtMs(nowMs) - nowMs);
  timers.push(
    setTimeout(async () => {
      try {
        await runPurge(deps.sql, new Date());
        await runPurgeDiagnostics(deps.sql, new Date());
        await runPurgeLearning(deps.sql, new Date());
      } catch {
        console.log(
          JSON.stringify({ level: "error", msg: "purge failed" }),
        );
      }
      timers.push(setInterval(async () => {
        try {
          await runPurge(deps.sql, new Date());
          await runPurgeDiagnostics(deps.sql, new Date());
          await runPurgeLearning(deps.sql, new Date());
        } catch {
          console.log(
            JSON.stringify({ level: "error", msg: "purge failed" }),
          );
        }
      }, 86400 * 1000));
    }, purgeDelay),
  );
  timers.push(
    setInterval(async () => {
      await runDbHealth(deps.sql);
    }, deps.dbHealthMs),
  );

  return {
    stop() {
      for (const t of timers) {
        clearInterval(t);
        clearTimeout(t);
      }
    },
  };
}

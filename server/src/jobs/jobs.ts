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
): { ran: boolean; changedLines: number[] } {
  if (guard.running) return { ran: false, changedLines: [] };
  guard.running = true;
  try {
    const out = tick(store, events, nowMs, engine);
    // The array is a scratch buffer: tick appends tripEnded events via
    // endTrip, and no consumer reads them (onTick uses changedLines only).
    // Drain it here so ended trips do not accumulate for the life of the
    // process. Callers that pre-fill the array for the engine call itself
    // are unaffected: the drain happens after tick returns.
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
export async function runPurgeDiagnostics(sql: Sql, now: Date): Promise<number> {
  const cutoff = new Date(now.getTime() - 14 * 86400 * 1000);
  return await purgeOldDiagnostics(sql, cutoff);
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
      } catch {
        console.log(
          JSON.stringify({ level: "error", msg: "purge failed" }),
        );
      }
      timers.push(setInterval(async () => {
        try {
          await runPurge(deps.sql, new Date());
          await runPurgeDiagnostics(deps.sql, new Date());
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

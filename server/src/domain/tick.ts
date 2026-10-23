// Periodic tick. Ends timed-out trips, reaps empty vehicles, re-elects
// leaders, and marks changed lines for snapshot emit. Pure; time is a
// parameter. Overlap guard lives in jobs/ (T11). See PLAN.md 6.6.
import { bestMember } from "./election.ts";
import { prunePassages } from "./arrivals.ts";
import { endTrip } from "./ping.ts";
import { pruneReports } from "./reports.ts";
import { membersOf, removeVehicle, vehiclesOfLine } from "./store.ts";
import type { Store } from "./store.ts";
import type { EngineConfig, EngineEvent } from "./types.ts";

export interface TickResult {
  changedLines: number[];
}

/** Run one tick. Returns the lines whose snapshots changed. */
export function tick(
  store: Store,
  events: EngineEvent[],
  nowMs: number,
  cfg: EngineConfig,
): TickResult {
  if (store.trips.size === 0 && store.vehicles.size === 0) {
    prunePassages(store, nowMs);
    return { changedLines: pruneReports(store, nowMs) };
  }
  const changed = new Set<number>();
  // Reports expire even when no vehicle is live on the line.
  for (const lineId of pruneReports(store, nowMs)) changed.add(lineId);

  for (const trip of [...store.trips.values()]) {
    if (trip.lastSeenAtMs === null) continue;
    if (nowMs - trip.lastSeenAtMs > cfg.tripTimeoutS * 1000) {
      changed.add(trip.lineId);
      endTrip(store, events, trip.deviceId, "timeout");
    } else if (nowMs - trip.startedAtMs > cfg.tripMaxS * 1000) {
      changed.add(trip.lineId);
      endTrip(store, events, trip.deviceId, "max_duration");
    }
  }

  const lineIds = new Set<number>();
  for (const t of store.trips.values()) lineIds.add(t.lineId);
  for (const v of store.vehicles.values()) lineIds.add(v.lineId);

  for (const lineId of lineIds) {
    for (const v of vehiclesOfLine(store, lineId)) {
      const members = membersOf(store, v.id, nowMs, cfg.memberAliveS);
      if (members.length === 0) {
        removeVehicle(store, v.id);
        changed.add(lineId);
        continue;
      }
      const leader = v.leaderDeviceId
        ? members.find((m) => m.deviceId === v.leaderDeviceId) ?? null
        : null;
      const leaderAlive = leader !== null &&
        leader.lastSeenAtMs !== null &&
        nowMs - leader.lastSeenAtMs <= cfg.leaderDeadAfterS * 1000;
      if (!leaderAlive) {
        // Prefer a fresh member so a dead leader is never re-picked while a
        // live follower waits. Falls back to all members when all are stale.
        // See DECISIONS.md T09 note.
        const fresh = members.filter((m) =>
          m.lastSeenAtMs !== null &&
          nowMs - m.lastSeenAtMs <= cfg.leaderDeadAfterS * 1000
        );
        const next = bestMember(fresh.length > 0 ? fresh : members, cfg);
        v.leaderDeviceId = next ? next.deviceId : null;
        v.nextLeaderDeviceId = null;
        v.lastElectAtMs = nowMs;
        changed.add(lineId);
      } else if (nowMs - v.lastElectAtMs >= cfg.reelectEveryS * 1000) {
        const cand = bestMember(members, cfg);
        if (cand && cand.deviceId !== v.leaderDeviceId) {
          v.nextLeaderDeviceId = cand.deviceId;
          v.lastElectAtMs = nowMs;
          changed.add(lineId);
        } else {
          v.lastElectAtMs = nowMs;
        }
      }
      if (v.leaderDeviceId) {
        const trip = store.trips.get(v.leaderDeviceId);
        if (trip) trip.ledS += cfg.tickPeriodS;
      }
    }
  }

  prunePassages(store, nowMs);
  return { changedLines: [...changed] };
}

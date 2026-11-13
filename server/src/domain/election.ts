// Leader election. Pure. Prefers charging, then highest battery at or
// above the minimum unless alone, tie goes to least time led.
// See ARCHITECTURE.md RF07 and 6.6 tick step 2.
import type { EngineConfig, Trip } from "./types.ts";

/** Rank members; first element wins. */
export function bestMember(members: Trip[], cfg: EngineConfig): Trip | null {
  if (members.length === 0) return null;
  if (members.length === 1) return members[0];
  const eligible = members.filter((m) => m.batteryPct >= cfg.leaderMinBattery);
  const pool = eligible.length > 0 ? eligible : members;
  const ranked = [...pool].sort((a, b) => {
    if (a.charging !== b.charging) return a.charging ? -1 : 1;
    if (a.batteryPct !== b.batteryPct) return b.batteryPct - a.batteryPct;
    if (a.ledS !== b.ledS) return a.ledS - b.ledS;
    return a.startedAtMs - b.startedAtMs;
  });
  return ranked[0];
}

// Guard state in one round trip. The ping hot path used to call isBlocked
// plus latestConsentVersion (two round trips per ping); this answers both
// at once with identical semantics. The pair stays for their own callers
// and tests. See PLAN.md 6.9.
import type { Sql } from "./client.ts";

export interface GuardState {
  blocked: boolean;
  consent: number | null;
}

export async function guardState(
  sql: Sql,
  deviceId: string,
): Promise<GuardState> {
  const rows = await sql`
    select
      exists(select 1 from blocked_devices where device_id = ${deviceId}) as blocked,
      (select max(version) from consents where device_id = ${deviceId}) as consent`;
  const row = rows[0] as { blocked: boolean; consent: number | null };
  return { blocked: row.blocked, consent: row.consent };
}

// Diagnostics repository. Stores redacted bundles only. No location.
import type { Sql } from "./client.ts";

export async function insertDiagnostic(
  sql: Sql,
  deviceId: string | null,
  payload: unknown,
): Promise<void> {
  await sql`
    insert into diagnostics (device_id, payload)
    values (${deviceId}, ${
    sql.json(payload as unknown as Parameters<typeof sql.json>[0])
  })
  `;
}

export async function purgeOldDiagnostics(
  sql: Sql,
  cutoff: Date,
): Promise<number> {
  let total = 0;
  for (;;) {
    const rows = await sql`
      delete from diagnostics
      where id in (
        select id from diagnostics where created_at < ${cutoff} limit 1000
      )
      returning id
    `;
    total += rows.length;
    if (rows.length < 1000) return total;
  }
}

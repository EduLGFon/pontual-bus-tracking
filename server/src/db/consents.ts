// Consent repository. Records consent version per device.
// SECURITY: scoped by authenticated device id only.
import type { Sql } from "./client.ts";

export async function recordConsent(
  sql: Sql,
  deviceId: string,
  version: number,
): Promise<void> {
  await sql`
    insert into consents (device_id, version) values (${deviceId}, ${version})
    on conflict (device_id, version) do nothing`;
}

export async function latestConsentVersion(
  sql: Sql,
  deviceId: string,
): Promise<number | null> {
  const rows = await sql`
    select version from consents where device_id = ${deviceId}
    order by version desc limit 1`;
  const row = rows[0] as { version: number } | undefined;
  return row ? row.version : null;
}

export async function revokeConsent(
  sql: Sql,
  deviceId: string,
): Promise<void> {
  await sql`delete from consents where device_id = ${deviceId}`;
}

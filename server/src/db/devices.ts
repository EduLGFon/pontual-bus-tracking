// Device repository. Pseudonymous rows only, no location.
// SECURITY: every lookup is scoped by the authenticated device id or its
// token hash derived server-side. Never accept ownership from the client.
import type { Sql } from "./client.ts";

export interface DeviceRow {
  id: string;
  tokenHash: Uint8Array;
  createdAt: Date;
  lastSeenAt: Date;
  expiresAt: Date;
}

export async function insertDevice(
  sql: Sql,
  tokenHash: Uint8Array,
  expiresAt: Date,
): Promise<DeviceRow> {
  const rows = await sql`
    insert into devices (token_hash, expires_at)
    values (${tokenHash}, ${expiresAt})
    returning id, token_hash as "tokenHash", created_at as "createdAt",
      last_seen_at as "lastSeenAt", expires_at as "expiresAt"`;
  return rows[0] as DeviceRow;
}

export async function findDeviceByTokenHash(
  sql: Sql,
  tokenHash: Uint8Array,
): Promise<DeviceRow | null> {
  const rows = await sql`
    select id, token_hash as "tokenHash", created_at as "createdAt",
      last_seen_at as "lastSeenAt", expires_at as "expiresAt"
    from devices where token_hash = ${tokenHash} limit 1`;
  return (rows[0] as DeviceRow | undefined) ?? null;
}

export async function deleteDevice(sql: Sql, deviceId: string): Promise<void> {
  await sql`delete from devices where id = ${deviceId}`;
}

export async function setLearningOptOut(
  sql: Sql,
  deviceId: string,
  optOut: boolean,
): Promise<void> {
  await sql`update devices set learning_opt_out = ${optOut} where id = ${deviceId}`;
}

export async function getLearningOptOut(
  sql: Sql,
  deviceId: string,
): Promise<boolean> {
  const rows = await sql`
    select learning_opt_out as "optOut" from devices where id = ${deviceId} limit 1`;
  return (rows[0] as { optOut: boolean } | undefined)?.optOut ?? false;
}

export async function purgeExpiredDevices(
  sql: Sql,
  now: Date,
): Promise<number> {
  // Batched so one daily purge never holds a huge write transaction
  // open as the device table grows.
  let total = 0;
  for (;;) {
    const rows = await sql`
      delete from devices
      where id in (
        select id from devices where expires_at <= ${now} limit 1000
      )
      returning id
    `;
    total += rows.length;
    if (rows.length < 1000) return total;
  }
}

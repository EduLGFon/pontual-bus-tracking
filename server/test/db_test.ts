// T07 DB integration: devices, consents, blocked, runtime config.
// Runs against TEST_DATABASE_URL (local Docker Postgres). Tables are
// truncated between tests; each test owns its rows by device id.
import { assertEquals } from "@std/assert";
import { openDb } from "../src/db/client.ts";
import {
  deleteDevice,
  findDeviceByTokenHash,
  insertDevice,
  purgeExpiredDevices,
} from "../src/db/devices.ts";
import { latestConsentVersion, recordConsent } from "../src/db/consents.ts";
import { blockDevice, isBlocked } from "../src/db/blocked.ts";
import { guardState } from "../src/db/guard.ts";
import {
  defaultRuntimeConfig,
  loadRuntimeConfig,
} from "../src/config/runtime.ts";

function testDbUrl(): string {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  return url;
}

async function truncate(sql: ReturnType<typeof openDb>): Promise<void> {
  await sql`truncate devices, app_config restart identity cascade`;
}

Deno.test("devices insert, lookup by hash, delete cascades", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    const hash = crypto.getRandomValues(new Uint8Array(32));
    const exp = new Date(Date.now() + 30 * 86400 * 1000);
    const row = await insertDevice(sql, hash, exp);
    const found = await findDeviceByTokenHash(sql, hash);
    assertEquals(found?.id, row.id);
    await deleteDevice(sql, row.id);
    assertEquals(await findDeviceByTokenHash(sql, hash), null);
  } finally {
    await sql.end();
  }
});

Deno.test("consents record and latest version per device", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    const hash = crypto.getRandomValues(new Uint8Array(32));
    const device = await insertDevice(
      sql,
      hash,
      new Date(Date.now() + 86400 * 1000),
    );
    assertEquals(await latestConsentVersion(sql, device.id), null);
    await recordConsent(sql, device.id, 1);
    assertEquals(await latestConsentVersion(sql, device.id), 1);
  } finally {
    await sql.end();
  }
});

Deno.test("blocked devices flag by device id", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    const hash = crypto.getRandomValues(new Uint8Array(32));
    const device = await insertDevice(
      sql,
      hash,
      new Date(Date.now() + 86400 * 1000),
    );
    assertEquals(await isBlocked(sql, device.id), false);
    await blockDevice(sql, device.id, "test");
    assertEquals(await isBlocked(sql, device.id), true);
  } finally {
    await sql.end();
  }
});

Deno.test("guard state answers block plus consent together", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    const hash = crypto.getRandomValues(new Uint8Array(32));
    const device = await insertDevice(
      sql,
      hash,
      new Date(Date.now() + 86400 * 1000),
    );
    assertEquals(
      await guardState(sql, device.id),
      { blocked: false, consent: null },
    );
    await recordConsent(sql, device.id, 1);
    assertEquals(
      await guardState(sql, device.id),
      { blocked: false, consent: 1 },
    );
    await blockDevice(sql, device.id, "test");
    assertEquals(
      await guardState(sql, device.id),
      { blocked: true, consent: 1 },
    );
  } finally {
    await sql.end();
  }
});

Deno.test("expired devices purge", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    const hash = crypto.getRandomValues(new Uint8Array(32));
    await insertDevice(sql, hash, new Date(Date.now() - 1000));
    assertEquals(await purgeExpiredDevices(sql, new Date()), 1);
  } finally {
    await sql.end();
  }
});

Deno.test("runtime config defaults with empty table", async () => {
  const sql = openDb(testDbUrl());
  try {
    await truncate(sql);
    assertEquals(await loadRuntimeConfig(sql), defaultRuntimeConfig());
    await sql`insert into app_config (key, value) values ('service_enabled', 'false')`;
    assertEquals((await loadRuntimeConfig(sql)).serviceEnabled, false);
  } finally {
    await sql.end();
  }
});

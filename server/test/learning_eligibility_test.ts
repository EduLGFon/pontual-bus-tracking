// HTTP-level eligibility tests for the per-device learning counter (D98):
// a fresh start increments once, a resume never does, and opt-out keeps it
// at 0. Runs the real app in-process against test PostgreSQL, mirroring
// trip_test.ts. See docs/data-learning.md section 4.4.
import { assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb, type Sql } from "../src/db/client.ts";
import { getLearningTrips } from "../src/db/devices.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { LearningConsumer } from "../src/learning/consumer.ts";
import { defaultLearningConfig } from "../src/learning/types.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";

function testDbUrl(): string {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  return url;
}

async function truncate(): Promise<void> {
  const sql = openDb(testDbUrl());
  try {
    await sql`truncate devices, app_config restart identity cascade`;
  } finally {
    await sql.end();
  }
}

/** Build the HTTP app on an existing connection. */
function honoFor(appSql: Sql): ReturnType<typeof buildApp> {
  const learning = new LearningConsumer({
    sql: appSql,
    config: defaultLearningConfig,
    now: Date.now,
    privacyMode: () => "all",
  });
  return buildApp({
    sql: appSql,
    store: createStore(),
    lines: registryResolver([{ id: 7, isActive: true, route: null }]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: () => {},
    reportsEnabled: () => false,
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
    learning,
  });
}

function app() {
  const sql = openDb(testDbUrl());
  return { sql, hono: honoFor(sql) };
}

/**
 * Sql proxy that rejects queries touching one learning column, like a
 * database where migration 0005 has not run. Every other tagged-template
 * query passes through.
 */
function withoutSchema(sql: Sql, column: string): Sql {
  const base = sql as unknown as (
    strings: TemplateStringsArray,
    ...values: unknown[]
  ) => Promise<unknown[]>;
  return ((strings: TemplateStringsArray, ...values: unknown[]) => {
    const text = strings.join("?");
    if (text.includes(column)) {
      return Promise.reject(new Error("learning schema unavailable"));
    }
    return base(strings, ...values);
  }) as unknown as Sql;
}

async function device(hono: ReturnType<typeof buildApp>): Promise<string> {
  const reg = await hono.request("/v1/devices", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assertEquals(reg.status, 201);
  const { token } = await reg.json() as { token: string };
  const consent = await hono.request("/v1/consents", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: '{"version":2}',
  });
  assertEquals(consent.status, 200);
  return token;
}

function startBody(resume = false): string {
  return JSON.stringify({
    line: 7,
    lat: -18.72,
    lng: -39.85,
    acc: 10,
    bat: 80,
    chg: false,
    ...(resume ? { resume: true } : {}),
  });
}

async function start(
  hono: ReturnType<typeof buildApp>,
  token: string,
  resume = false,
): Promise<void> {
  const r = await hono.request("/v1/trip", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: startBody(resume),
  });
  assertEquals(r.status, 201);
}

/** Single device row after truncate restart identity. */
async function deviceId(sql: Sql): Promise<string> {
  const rows = await sql`select id from devices limit 1`;
  return (rows[0] as { id: string }).id;
}

Deno.test({
  name: "five sequential starts leave the learning counter at 5",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const { sql, hono } = app();
    try {
      const token = await device(hono);
      for (let i = 0; i < 5; i++) await start(hono, token);
      assertEquals(await getLearningTrips(sql, await deviceId(sql)), 5);
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name: "a resume start does not change the learning counter",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const { sql, hono } = app();
    try {
      const token = await device(hono);
      await start(hono, token);
      const before = await getLearningTrips(sql, await deviceId(sql));
      assertEquals(before, 1);
      await start(hono, token, true);
      assertEquals(
        await getLearningTrips(sql, await deviceId(sql)),
        before,
      );
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name: "opted-out device keeps the learning counter at 0",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const { sql, hono } = app();
    try {
      const token = await device(hono);
      const optOut = await hono.request("/v1/me/learning", {
        method: "DELETE",
        headers: { authorization: `Bearer ${token}` },
      });
      assertEquals(optOut.status, 204);
      await start(hono, token);
      assertEquals(await getLearningTrips(sql, await deviceId(sql)), 0);
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name: "trip start succeeds when learning_trips is missing",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const sql = openDb(testDbUrl());
    try {
      // getLearningOptOut succeeds, then bumpLearningTrips throws before any
      // counter write or event application.
      const hono = honoFor(withoutSchema(sql, "learning_trips"));
      const token = await device(hono);
      await start(hono, token);
      assertEquals(await getLearningTrips(sql, await deviceId(sql)), 0);

      // A later start on a healthy app still increments the counter.
      const healthy = app();
      try {
        await start(healthy.hono, token);
        assertEquals(await getLearningTrips(sql, await deviceId(sql)), 1);
      } finally {
        await healthy.sql.end();
      }
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name: "trip start succeeds when learning_opt_out is missing",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const sql = openDb(testDbUrl());
    try {
      // Opt-out cannot be established, so nothing is contributed.
      const hono = honoFor(withoutSchema(sql, "learning_opt_out"));
      const token = await device(hono);
      await start(hono, token);
      assertEquals(await getLearningTrips(sql, await deviceId(sql)), 0);
    } finally {
      await sql.end();
    }
  },
});

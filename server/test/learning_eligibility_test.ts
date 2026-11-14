// Consent acceptance tests for learning contribution. Every finalized trip
// from a consenting, non-opted-out device contributes; there is no per-device
// trip-count gate (D98 is superseded). Old consent and opt-out still skip.
// Non-DB cases use the shared stateful fake Sql; the opt-out path runs the
// real app in-process
// against test PostgreSQL, mirroring trip_test.ts.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb, type Sql } from "../src/db/client.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { LearningConsumer } from "../src/learning/consumer.ts";
import {
  defaultLearningConfig,
  type LearningConfig,
} from "../src/learning/types.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";
import { fakeSql } from "./learning_fake_sql.ts";

function testConfig(): LearningConfig {
  return {
    ...defaultLearningConfig(),
    trimEndsS: 0,
    minSampleSpacingM: 0,
    minSampleSpacingS: 0,
  };
}

/** Consume one moving trip; the caller decides which queries to assert. */
function runTrip(consumer: LearningConsumer, consentVersion: number): void {
  const t0 = 1_000_000;
  const opts = { consentVersion };
  consumer.handle({
    kind: "tripStarted",
    lineId: 7,
    tripKey: "trip",
    startedAtMs: t0,
    lat: -18.72,
    lng: -39.85,
  }, opts);
  for (let i = 1; i <= 10; i++) {
    consumer.handle({
      kind: "fixAccepted",
      lineId: 7,
      tripKey: "trip",
      atMs: t0 + i * 5000,
      lat: -18.72,
      lng: -39.85 + i * 0.0005,
      speedMps: 10,
      heading: null,
      accuracyM: 5,
    }, opts);
  }
  consumer.handle({
    kind: "tripEnded",
    lineId: 7,
    tripKey: "trip",
    reason: "user",
  }, opts);
}

function consumerFor(sql: Sql): LearningConsumer {
  return new LearningConsumer({
    sql,
    config: () => testConfig(),
    now: () => 1_060_000,
  });
}

Deno.test("a consenting trip contributes on its first trip", async () => {
  const { sql, queries } = fakeSql();
  const consumer = consumerFor(sql);
  runTrip(consumer, defaultLearningConfig().minConsentVersion);
  await consumer.flush();

  assert(
    queries.some((q) => q.text.includes("insert into learning_route_cells")),
    "expected cell accumulation",
  );
  assert(
    queries.some((q) => q.text.includes("insert into learning_route_state")),
    "expected the per-direction sample counter to increment",
  );
  assert(
    queries.some((q) => q.text.includes("insert into learned_routes")),
    "expected a route publication",
  );
});

Deno.test("old consent never contributes", async () => {
  const { sql, queries } = fakeSql();
  const consumer = consumerFor(sql);
  runTrip(consumer, defaultLearningConfig().minConsentVersion - 1);
  await consumer.flush();

  const writes = queries.filter((q) =>
    q.text.includes("insert into learning_route_cells") ||
    q.text.includes("insert into learning_route_edges") ||
    q.text.includes("insert into learning_route_state") ||
    q.text.includes("insert into learned_routes")
  );
  assertEquals(
    writes.map((q) => q.text),
    [],
  );
});

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

/**
 * App with a learning consumer spy. Only `handle` is used by the trip routes,
 * so the spy records whether events reached the learning subsystem.
 */
function honoFor(
  appSql: Sql,
  onHandle: () => void,
): ReturnType<typeof buildApp> {
  const learning = {
    handle: () => onHandle(),
  } as unknown as LearningConsumer;
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

/** Sql proxy that rejects queries touching one learning column. */
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

async function start(
  hono: ReturnType<typeof buildApp>,
  token: string,
): Promise<void> {
  const r = await hono.request("/v1/trip", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      line: 7,
      lat: -18.72,
      lng: -39.85,
      acc: 10,
      bat: 80,
      chg: false,
    }),
  });
  assertEquals(r.status, 201);
}

Deno.test({
  name: "consenting device trip start reaches the learning consumer",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const sql = openDb(testDbUrl());
    try {
      let handled = 0;
      const hono = honoFor(sql, () => handled += 1);
      const token = await device(hono);
      await start(hono, token);
      assertEquals(handled, 1);
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name: "opted-out device never reaches the learning consumer",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const sql = openDb(testDbUrl());
    try {
      let handled = 0;
      const hono = honoFor(sql, () => handled += 1);
      const token = await device(hono);
      const optOut = await hono.request("/v1/me/learning", {
        method: "DELETE",
        headers: { authorization: `Bearer ${token}` },
      });
      assertEquals(optOut.status, 204);
      await start(hono, token);
      assertEquals(handled, 0);
    } finally {
      await sql.end();
    }
  },
});

Deno.test({
  name:
    "trip start succeeds and contributes nothing when learning_opt_out is missing",
  ignore: !Deno.env.get("TEST_DATABASE_URL"),
  fn: async () => {
    await truncate();
    const sql = openDb(testDbUrl());
    try {
      // Opt-out cannot be established, so no event reaches the consumer.
      let handled = 0;
      const hono = honoFor(
        withoutSchema(sql, "learning_opt_out"),
        () => handled += 1,
      );
      const token = await device(hono);
      await start(hono, token);
      assertEquals(handled, 0);
    } finally {
      await sql.end();
    }
  },
});

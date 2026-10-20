// Passenger reports: pure TTL/count rules, coarse area validation, auth,
// the snapshot field, retraction and DELETE /v1/me cleanup.
// See DECISIONS.md#D82/D83 and D83.
import { assert, assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { openDb } from "../src/db/client.ts";
import { defaultRuntimeConfig } from "../src/config/runtime.ts";
import {
  applyReport,
  defaultReportsConfig,
  pruneReports,
  removeDeviceFromReports,
  reportRows,
  retractReport,
  targetMismatch,
} from "../src/domain/reports.ts";
import { areaIdOf, isAreaInServedBBox } from "../src/domain/areas.ts";
import { buildApp } from "../src/http/app.ts";
import { createStore } from "../src/state/store.ts";
import { Hub } from "../src/ws/hub.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";

const AREA = "g52902_98514";

function testDbUrl(): string {
  const url = Deno.env.get("TEST_DATABASE_URL");
  if (!url) throw new Error("TEST_DATABASE_URL is not set");
  return url;
}

async function truncate(sql: ReturnType<typeof openDb>): Promise<void> {
  await sql`truncate devices, app_config restart identity cascade`;
}

function app() {
  const sql = openDb(testDbUrl());
  const store = createStore();
  const runtime = defaultRuntimeConfig();
  const changes: number[] = [];
  const hono = buildApp({
    sql,
    store,
    lines: registryResolver([{ id: 7, isActive: true, route: null }]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: (lineId) => changes.push(lineId),
    reportsEnabled: () => runtime.reports.enabled,
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
    runtime: () => Promise.resolve(runtime),
  });
  return { sql, hono, store, runtime, changes };
}

async function register(hono: ReturnType<typeof buildApp>): Promise<string> {
  const res = await hono.request("/v1/devices", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  });
  assertEquals(res.status, 201);
  const body = await res.json() as { token: string };
  return body.token;
}

function postReport(
  hono: ReturnType<typeof buildApp>,
  token: string,
  body: Record<string, unknown>,
): Response | Promise<Response> {
  return hono.request("/v1/reports", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });
}

Deno.test("reports domain: kind-target rules and area encoding", () => {
  assertEquals(targetMismatch("waiting", null), true);
  assertEquals(targetMismatch("blocked", null), true);
  assertEquals(targetMismatch("broken", AREA), true);
  assertEquals(targetMismatch("full", AREA), true);
  assertEquals(targetMismatch("waiting", AREA), false);
  assertEquals(targetMismatch("broken", null), false);
  assertEquals(areaIdOf(-18.7156, -39.8568), AREA);
  assertEquals(isAreaInServedBBox(AREA), true);
  assertEquals(isAreaInServedBBox("g0_0"), false);
});

Deno.test("reports domain: count, refresh, cap, expiry and retract", () => {
  const store = createStore();
  const cfg = defaultReportsConfig();
  const t0 = 1_000_000;
  const first = applyReport(store, 7, "waiting", AREA, "d1", t0, cfg);
  assert(first.ok && first.created);
  let rows = reportRows(store, 7, t0);
  assertEquals(rows.length, 1);
  assertEquals(rows[0].count, 1);
  assertEquals(rows[0].area, AREA);

  const second = applyReport(store, 7, "waiting", AREA, "d2", t0 + 1000, cfg);
  assert(second.ok && !second.created);
  rows = reportRows(store, 7, t0 + 1000);
  assertEquals(rows[0].count, 2);

  const repeat = applyReport(store, 7, "waiting", AREA, "d1", t0 + 2000, cfg);
  assert(repeat.ok);
  rows = reportRows(store, 7, t0 + 2000);
  assertEquals(rows[0].count, 2);
  assertEquals(rows[0].updated_age_s, 0);

  const retract = retractReport(store, 7, "waiting", AREA, "d2");
  assertEquals(retract.changed, true);
  assertEquals(retract.removed, false);
  assertEquals(reportRows(store, 7, t0 + 3000)[0].count, 1);

  const gone = retractReport(store, 7, "waiting", AREA, "d1");
  assertEquals(gone.removed, true);
  assertEquals(reportRows(store, 7, t0 + 3000).length, 0);

  const mixed = applyReport(store, 7, "broken", null, "d1", t0, cfg);
  assert(mixed.ok);
  assertEquals(reportRows(store, 7, t0 + cfg.ttlS.broken * 1000).length, 0);
  assertEquals(pruneReports(store, t0 + cfg.ttlS.broken * 1000), [7]);
});

Deno.test("reports domain: per-line cap rejects a new report", () => {
  const store = createStore();
  const cfg = { ...defaultReportsConfig(), maxPerLine: 1 };
  assert(applyReport(store, 7, "broken", null, "d1", 1000, cfg).ok);
  const out = applyReport(store, 7, "full", null, "d2", 1000, cfg);
  assertEquals(out.ok, false);
});

Deno.test("reports domain: delete-me cleanup removes the device", () => {
  const store = createStore();
  const cfg = defaultReportsConfig();
  assert(applyReport(store, 7, "waiting", AREA, "d1", 1000, cfg).ok);
  assert(applyReport(store, 7, "waiting", AREA, "d2", 1000, cfg).ok);
  const changed = removeDeviceFromReports(store, "d2");
  assertEquals(changed, [7]);
  assertEquals(reportRows(store, 7, 1000)[0].count, 1);
  removeDeviceFromReports(store, "d1");
  assertEquals(reportRows(store, 7, 1000).length, 0);
});

Deno.test("POST /v1/reports: auth, schema, area validation and snapshot", async () => {
  const { sql, hono, store, changes } = app();
  try {
    await truncate(sql);
    assertEquals(
      (await postReport(hono, "bad", { op: "report", kind: "broken", line: 7 }))
        .status,
      401,
    );
    const token = await register(hono);

    const created = await postReport(hono, token, {
      op: "report",
      kind: "broken",
      line: 7,
    });
    assertEquals(created.status, 201);
    const createdBody = await created.json() as {
      t: number;
      r: { kind: string; count: number; area: string | null }[];
    };
    assertEquals(createdBody.r[0].kind, "broken");
    assertEquals(createdBody.r[0].count, 1);
    assertEquals(createdBody.r[0].area, null);
    assertEquals(changes, [7]);

    const snap = await hono.request("/v1/lines/7/vehicles");
    assertEquals(snap.status, 200);
    const snapBody = await snap.json() as {
      r: { kind: string; area: string | null }[];
    };
    assertEquals(snapBody.r[0].kind, "broken");
    assertEquals(snapBody.r[0].area, null);

    // Unknown keys (including coordinates) are rejected at the boundary.
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "broken",
        line: 7,
        lat: -18.7,
      })).status,
      400,
    );
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "waiting",
        line: 7,
      })).status,
      400,
    );
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "broken",
        line: 7,
        area: AREA,
      })).status,
      400,
    );
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "waiting",
        line: 7,
        area: "nope",
      })).status,
      400,
    );
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "waiting",
        line: 7,
        area: "g0_0",
      })).status,
      400,
    );
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "waiting",
        line: 999,
        area: AREA,
      })).status,
      404,
    );

    const waiting = await postReport(hono, token, {
      op: "report",
      kind: "waiting",
      line: 7,
      area: AREA,
    });
    assertEquals(waiting.status, 201);
    assertEquals(reportRows(store, 7, Date.now()).length, 2);

    const retracted = await postReport(hono, token, {
      op: "retract",
      kind: "waiting",
      line: 7,
      area: AREA,
    });
    assertEquals(retracted.status, 200);
    assertEquals(reportRows(store, 7, Date.now()).length, 1);
  } finally {
    await sql.end();
  }
});

Deno.test("POST /v1/reports: kill switch and delete-me cleanup", async () => {
  const { sql, hono, store, runtime } = app();
  try {
    await truncate(sql);
    const token = await register(hono);
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "broken",
        line: 7,
      })).status,
      201,
    );
    runtime.reports.enabled = false;
    assertEquals(
      (await postReport(hono, token, {
        op: "report",
        kind: "broken",
        line: 7,
      })).status,
      503,
    );
    runtime.reports.enabled = true;

    const deleted = await hono.request("/v1/me", {
      method: "DELETE",
      headers: { authorization: `Bearer ${token}` },
    });
    assertEquals(deleted.status, 204);
    assertEquals(reportRows(store, 7, Date.now()).length, 0);
  } finally {
    await sql.end();
  }
});

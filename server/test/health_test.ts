import { assertEquals } from "@std/assert";
import { registryResolver } from "../src/data/lines.ts";
import { defaultEngineConfig } from "../src/domain/types.ts";
import { buildApp } from "../src/http/app.ts";
import { Hub } from "../src/ws/hub.ts";

function testApp() {
  return buildApp({
    sql: null,
    store: null,
    lines: registryResolver([]),
    hub: new Hub(),
    followerJitterS: 0,
    onLineChanged: () => {},
    stops: () => true,
    reportsEnabled: () => false,
    trustCloudflare: false,
    allowedOrigins: [],
    engine: defaultEngineConfig(),
  });
}

Deno.test("GET /v1/health returns ok", async () => {
  const app = testApp();
  const res = await app.request("/v1/health");
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { ok: true });
});

Deno.test("unknown path returns generic not_found", async () => {
  const app = testApp();
  const res = await app.request("/admin");
  assertEquals(res.status, 404);
  assertEquals(await res.json(), { code: "not_found" });
});

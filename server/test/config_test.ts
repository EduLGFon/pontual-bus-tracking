import { assertEquals, assertThrows } from "@std/assert";
import { loadConfig } from "../src/config/config.ts";

function baseEnv(): Record<string, string | undefined> {
  return {
    APP_ENV: "local",
    HOST: "127.0.0.1",
    PORT: "8080",
    DATABASE_URL: "postgresql://user:pass@127.0.0.1:5432/dbname",
    ALLOWED_ORIGINS: "http://127.0.0.1:8080",
    TRUST_CLOUDFLARE: "false",
    DATA_DIR: "./build",
    LOG_LEVEL: "info",
    METRICS_PORT: "127.0.0.1:9091",
  };
}

Deno.test("valid env loads", () => {
  const cfg = loadConfig(baseEnv());
  assertEquals(cfg.port, 8080);
  assertEquals(cfg.metricsPort, 9091);
});

Deno.test("missing env refuses to start", () => {
  const env = baseEnv();
  delete env.DATABASE_URL;
  assertThrows(() => loadConfig(env), Error, "missing env DATABASE_URL");
});

Deno.test("invalid env refuses to start", () => {
  const badPort = { ...baseEnv(), PORT: "abc" };
  assertThrows(() => loadConfig(badPort), Error, "invalid env PORT");
  const badEnv = { ...baseEnv(), APP_ENV: "qa" };
  assertThrows(() => loadConfig(badEnv), Error, "invalid env APP_ENV");
  const badLines = { ...baseEnv(), LINES_JSON: "[1]" };
  assertThrows(() => loadConfig(badLines), Error, "invalid env LINES_JSON");
});

Deno.test("lines seed defaults empty and parses", () => {
  assertEquals(loadConfig(baseEnv()).linesJson, []);
  const cfg = loadConfig({
    ...baseEnv(),
    LINES_JSON: '[{"id":7,"isActive":true}]',
  });
  assertEquals(cfg.linesJson, [{ id: 7, isActive: true }]);
});

Deno.test("learning privacy mode defaults to all", () => {
  assertEquals(loadConfig(baseEnv()).learningPrivacyMode, "all");
});

Deno.test("learning privacy mode accepts explicit values", () => {
  assertEquals(
    loadConfig({ ...baseEnv(), LEARNING_PRIVACY_MODE: "all" })
      .learningPrivacyMode,
    "all",
  );
  assertEquals(
    loadConfig({ ...baseEnv(), LEARNING_PRIVACY_MODE: "route_stops" })
      .learningPrivacyMode,
    "route_stops",
  );
});

Deno.test("invalid learning privacy mode refuses to start", () => {
  assertThrows(
    () => loadConfig({ ...baseEnv(), LEARNING_PRIVACY_MODE: "off" }),
    Error,
    "invalid env LEARNING_PRIVACY_MODE",
  );
});

Deno.test("easy publish defaults off and stays local", () => {
  assertEquals(loadConfig(baseEnv()).testEasyPublish, false);
  const local = loadConfig({ ...baseEnv(), TEST_EASY_PUBLISH: "true" });
  assertEquals(local.testEasyPublish, true);
  assertThrows(
    () => loadConfig({ ...baseEnv(), TEST_EASY_PUBLISH: "yes" }),
    Error,
    "invalid env TEST_EASY_PUBLISH",
  );
  assertThrows(
    () =>
      loadConfig({
        ...baseEnv(),
        APP_ENV: "staging",
        TEST_EASY_PUBLISH: "true",
      }),
    Error,
    "invalid env TEST_EASY_PUBLISH",
  );
});

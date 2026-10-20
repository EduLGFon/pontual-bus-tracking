// Bootstrap: config, HTTP server, internal metrics listener, shutdown.
// See PLAN.md 6.2, 6.9, 6.10.
import { loadConfig } from "./config/config.ts";
import { defaultRuntimeConfig, loadRuntimeConfig } from "./config/runtime.ts";
import { loadLinesFromDir, registryResolver } from "./data/lines.ts";
import { openDb } from "./db/client.ts";
import { reportRows } from "./domain/reports.ts";
import { defaultEngineConfig } from "./domain/types.ts";
import { buildApp } from "./http/app.ts";
import { startJobs } from "./jobs/jobs.ts";
import { setLogLevel } from "./observability/log.ts";
import { snapshot } from "./observability/metrics.ts";
import { pruneLimiters } from "./security/rateLimit.ts";
import { createStore } from "./state/store.ts";
import { snapshotRows } from "./state/snapshots.ts";
import { Hub } from "./ws/hub.ts";

function readEnv(): Record<string, string | undefined> {
  const names = [
    "APP_ENV",
    "HOST",
    "PORT",
    "DATABASE_URL",
    "ALLOWED_ORIGINS",
    "TRUST_CLOUDFLARE",
    "DATA_DIR",
    "LOG_LEVEL",
    "METRICS_PORT",
    "LINES_JSON",
    "TEST_EASY_PUBLISH",
  ];
  const out: Record<string, string | undefined> = {};
  for (const n of names) out[n] = Deno.env.get(n);
  return out;
}

const config = loadConfig(readEnv());
setLogLevel(config.logLevel);

const sql = openDb(config.databaseUrl);
// Runtime config: compiled defaults until the database answers, then
// the 30 s refresh job below keeps it fresh. Reads never block on it,
// so the API still boots and serves snapshots with the DB down.
let runtime = defaultRuntimeConfig();
loadRuntimeConfig(sql).then(
  (r) => {
    runtime = r;
  },
  () => {},
);
// Line registry: built bundle first, LINES_JSON local seed as fallback.
const bundled = await loadLinesFromDir(config.dataDir);
const seed = config.linesJson.map((l) => ({
  id: l.id,
  isActive: l.isActive,
  route: null,
}));
const registry = [
  ...bundled,
  ...seed.filter((s) => !bundled.some((b) => b.id === s.id)),
];
const lines = registryResolver(registry);
console.log(
  JSON.stringify({
    level: registry.length === 0 ? "warn" : "info",
    msg: "lines loaded",
    count: registry.length,
    dataDir: config.dataDir,
    hint: registry.length === 0
      ? "registry empty: reads 404; run the data build and set DATA_DIR"
      : undefined,
  }),
);
const store = createStore();
const hub = new Hub();
const engine = defaultEngineConfig();
if (config.testEasyPublish) {
  // Testing only: publish on the first ping and count every fix as
  // moving, so stationary field tests show a bus. Indoor fixes are
  // also coarse, so the accuracy gate is relaxed to match the
  // easy-test client env (FIX_ACCURACY_MAX_M). Refused outside local
  // by config validation. See DECISIONS.md.
  engine.movingSpeedMps = 0;
  engine.movingTicksToPublish = 1;
  engine.accuracyMaxM = 500;
  console.log(
    JSON.stringify({
      level: "warn",
      msg: "test easy-publish enabled",
      movingSpeedMps: engine.movingSpeedMps,
      movingTicksToPublish: engine.movingTicksToPublish,
      accuracyMaxM: engine.accuracyMaxM,
    }),
  );
}

function broadcastLine(lineId: number): void {
  const nowMs = Date.now();
  let payload: string;
  try {
    payload = JSON.stringify({
      l: lineId,
      t: Math.floor(nowMs / 1000),
      v: snapshotRows(
        store,
        lineId,
        nowMs,
        engine.publishTtlS,
        engine.memberAliveS,
      ),
      r: runtime.reports.enabled ? reportRows(store, lineId, nowMs) : [],
    });
  } catch {
    // Engine output is practically always valid JSON; if it ever is
    // not, skip this line instead of aborting the whole tick fan-out.
    console.log(
      JSON.stringify({ level: "error", msg: "bad snapshot", lineId }),
    );
    return;
  }
  hub.broadcast(lineId, payload);
}

const app = buildApp({
  sql,
  store,
  lines,
  hub,
  followerJitterS: 10,
  trustCloudflare: config.trustCloudflare,
  allowedOrigins: config.allowedOrigins,
  onLineChanged: broadcastLine,
  reportsEnabled: () => runtime.reports.enabled,
  engine,
  runtime: () => Promise.resolve(runtime),
});

const controller = new AbortController();

const server = Deno.serve(
  { hostname: config.host, port: config.port, signal: controller.signal },
  app.fetch,
);

// Internal metrics listener on localhost only. Never exposed via Cloudflare.
const metricsController = new AbortController();
const metricsServer = Deno.serve(
  {
    hostname: config.metricsHost,
    port: config.metricsPort,
    signal: metricsController.signal,
  },
  (_req) => Response.json(snapshot()),
);

function shutdown(): void {
  jobs.stop();
  clearInterval(heartbeat);
  hub.closeAll();
  controller.abort();
  metricsController.abort();
  void sql.end();
}

const jobs = startJobs({
  sql,
  store,
  engine,
  events: [],
  tickPeriodMs: engine.tickPeriodS * 1000,
  configRefreshMs: 30 * 1000,
  // Next 03:30 America/Sao_Paulo (fixed UTC-3, no DST since 2019).
  purgeAtMs: (nowMs: number) => {
    const sao = new Date(nowMs - 3 * 3600 * 1000);
    const next = new Date(sao);
    next.setUTCHours(3, 30, 0, 0);
    if (next.getTime() <= sao.getTime()) next.setUTCDate(next.getUTCDate() + 1);
    return next.getTime() + 3 * 3600 * 1000;
  },
  dbHealthMs: 10 * 1000,
  onTick: (changedLines) => {
    for (const lineId of changedLines) broadcastLine(lineId);
  },
  onConfig: (cfg) => {
    runtime = cfg;
  },
});

// Application heartbeat every 25 s for Cloudflare idle timeouts.
// Also prunes rate-limiter buckets so device/IP entries do not grow
// forever (each entry is tiny, but uptime is measured in weeks).
const heartbeat = setInterval(() => {
  hub.heartbeat(Math.floor(Date.now() / 1000));
  pruneLimiters(Date.now());
}, 25 * 1000);

Deno.addSignalListener("SIGTERM", shutdown);
Deno.addSignalListener("SIGINT", shutdown);

await Promise.all([server.finished, metricsServer.finished]);

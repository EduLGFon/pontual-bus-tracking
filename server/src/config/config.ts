// Server runtime config. Validated at boot; the process refuses to start
// on any invalid or missing value. See PLAN.md 6.3.
// No secrets are read from the repo; they come from the environment only.

export type AppEnv = "local" | "staging" | "prod";
export type LogLevel = "debug" | "info" | "warn" | "error";

export interface ServerConfig {
  appEnv: AppEnv;
  host: string;
  port: number;
  databaseUrl: string;
  allowedOrigins: string[];
  trustCloudflare: boolean;
  dataDir: string;
  logLevel: LogLevel;
  metricsHost: string;
  metricsPort: number;
  /** Local-dev line seed until the T14 bundle lands. Empty in staging/prod. */
  linesJson: { id: number; isActive: boolean }[];
  /**
   * Test-only relaxation: publish on the first ping and count every fix
   * as moving. Local only; refused in staging/prod.
   */
  testEasyPublish: boolean;
}

function required(
  name: string,
  env: Record<string, string | undefined>,
): string {
  const value = env[name];
  if (value === undefined || value === "") {
    throw new Error(`missing env ${name}`);
  }
  return value;
}

function parsePort(value: string, name: string): number {
  const n = Number(value);
  if (!Number.isInteger(n) || n < 1 || n > 65535) {
    throw new Error(`invalid env ${name}`);
  }
  return n;
}

function parseHostPort(
  value: string,
  name: string,
): { host: string; port: number } {
  const idx = value.lastIndexOf(":");
  if (idx < 0) throw new Error(`invalid env ${name}`);
  const host = value.slice(0, idx);
  const port = parsePort(value.slice(idx + 1), name);
  if (host === "") throw new Error(`invalid env ${name}`);
  return { host, port };
}

/** Parse and validate the process environment. Throws on any problem. */
export function loadConfig(
  env: Record<string, string | undefined>,
): ServerConfig {
  const appEnvRaw = required("APP_ENV", env);
  if (
    appEnvRaw !== "local" && appEnvRaw !== "staging" && appEnvRaw !== "prod"
  ) {
    throw new Error("invalid env APP_ENV");
  }
  const host = required("HOST", env);
  const port = parsePort(required("PORT", env), "PORT");
  const databaseUrl = required("DATABASE_URL", env);
  if (
    !databaseUrl.startsWith("postgresql://") &&
    !databaseUrl.startsWith("postgres://")
  ) {
    throw new Error("invalid env DATABASE_URL");
  }
  const allowedRaw = required("ALLOWED_ORIGINS", env);
  const allowedOrigins = allowedRaw
    .split(",")
    .map((s) => s.trim().replace(/\/+$/, ""))
    .filter((s) => s !== "");
  if (allowedOrigins.length === 0) {
    throw new Error("invalid env ALLOWED_ORIGINS");
  }
  const trustRaw = required("TRUST_CLOUDFLARE", env);
  if (trustRaw !== "true" && trustRaw !== "false") {
    throw new Error("invalid env TRUST_CLOUDFLARE");
  }
  const dataDir = required("DATA_DIR", env);
  const logRaw = required("LOG_LEVEL", env);
  if (
    logRaw !== "debug" && logRaw !== "info" && logRaw !== "warn" &&
    logRaw !== "error"
  ) {
    throw new Error("invalid env LOG_LEVEL");
  }
  const metrics = parseHostPort(required("METRICS_PORT", env), "METRICS_PORT");
  const easyRaw = env["TEST_EASY_PUBLISH"] ?? "false";
  if (easyRaw !== "true" && easyRaw !== "false") {
    throw new Error("invalid env TEST_EASY_PUBLISH");
  }
  const testEasyPublish = easyRaw === "true";
  if (testEasyPublish && appEnvRaw !== "local") {
    throw new Error("invalid env TEST_EASY_PUBLISH");
  }
  const linesRaw = env["LINES_JSON"] ?? "[]";
  let linesJson: { id: number; isActive: boolean }[];
  try {
    const parsed: unknown = JSON.parse(linesRaw);
    if (!Array.isArray(parsed)) throw new Error("not an array");
    linesJson = parsed.map((e) => {
      const id = (e as { id?: unknown }).id;
      const isActive = (e as { isActive?: unknown }).isActive;
      if (typeof id !== "number" || !Number.isInteger(id) || id < 1) {
        throw new Error("bad id");
      }
      if (typeof isActive !== "boolean") throw new Error("bad isActive");
      return { id, isActive };
    });
  } catch {
    throw new Error("invalid env LINES_JSON");
  }

  return {
    appEnv: appEnvRaw,
    host,
    port,
    databaseUrl,
    allowedOrigins,
    trustCloudflare: trustRaw === "true",
    dataDir,
    logLevel: logRaw,
    metricsHost: metrics.host,
    metricsPort: metrics.port,
    linesJson,
    testEasyPublish,
  };
}

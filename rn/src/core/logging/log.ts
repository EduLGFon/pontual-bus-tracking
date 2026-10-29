// Logging. No API accepts coordinates/tokens/ids. Mirrors app/lib/core/logging/log.dart.
type Level = "debug" | "info" | "warn" | "error";
function emit(level: Level, msg: string, ctx?: Record<string, unknown>) {
  const line = { level, msg, ...ctx };
  // eslint-disable-next-line no-console
  console[level === "debug" ? "log" : level](JSON.stringify(line));
}
export const Log = {
  debug: (msg: string, ctx?: Record<string, unknown>) => emit("debug", msg, ctx),
  info: (msg: string, ctx?: Record<string, unknown>) => emit("info", msg, ctx),
  warn: (msg: string, ctx?: Record<string, unknown>) => emit("warn", msg, ctx),
  error: (msg: string, ctx?: Record<string, unknown>) => emit("error", msg, ctx),
};

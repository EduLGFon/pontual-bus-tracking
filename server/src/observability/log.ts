// Structured log wrapper. Privacy by construction: there is no API that
// accepts coordinates, tokens, session ids, user ids, or device ids.
// Request logs carry method, route template, status, duration, request id.
// See PLAN.md 6.9 and 14.4.
// PRIVACY: never log coordinates.

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogFields {
  route?: string;
  method?: string;
  status?: number;
  durationMs?: number;
  requestId?: string;
  // Server Error message only, truncated by callers. Never request data,
  // coordinates, tokens, or ids. See PRIVACY note at the top of this file.
  err?: string;
}

const order: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

let current: LogLevel = "info";

export function setLogLevel(level: LogLevel): void {
  current = level;
}

function emit(level: LogLevel, msg: string, fields?: LogFields): void {
  if (order[level] < order[current]) return;
  const record: Record<string, unknown> = { level, msg, ...fields };
  console.log(JSON.stringify(record));
}

export const Log = {
  debug(msg: string, fields?: LogFields): void {
    emit("debug", msg, fields);
  },
  info(msg: string, fields?: LogFields): void {
    emit("info", msg, fields);
  },
  warn(msg: string, fields?: LogFields): void {
    emit("warn", msg, fields);
  },
  error(msg: string, fields?: LogFields): void {
    emit("error", msg, fields);
  },
};

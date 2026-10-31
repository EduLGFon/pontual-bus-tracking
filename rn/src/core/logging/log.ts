// Logging. No API accepts coordinates/tokens/ids. Mirrors app/lib/core/logging/log.dart.
import * as storage from "../../data/prefs/storage";

type Level = "debug" | "info" | "warn" | "error";

const DIAG_KEY = "diag_logs_v1";

function emit(level: Level, msg: string, ctx?: Record<string, unknown>) {
  const line = { level, msg, ...ctx };
  console[level === "debug" ? "log" : level](JSON.stringify(line));
  if (level === "warn" || level === "error") {
    void (async () => {
      try {
        const raw = await storage.getItem(DIAG_KEY);
        const list: unknown[] = raw ? (JSON.parse(raw) as unknown[]) : [];
        list.push({ l: level === "warn" ? "w" : "e", m: msg, c: ctx, t: Date.now() });
        while (list.length > 500) list.shift();
        await storage.setItem(DIAG_KEY, JSON.stringify(list));
      } catch {
        // Never fail logging.
      }
    })();
  }
}

export const Log = {
  debug: (msg: string, ctx?: Record<string, unknown>) => emit("debug", msg, ctx),
  info: (msg: string, ctx?: Record<string, unknown>) => emit("info", msg, ctx),
  warn: (msg: string, ctx?: Record<string, unknown>) => emit("warn", msg, ctx),
  error: (msg: string, ctx?: Record<string, unknown>) => emit("error", msg, ctx),
  readPersisted: async (): Promise<Record<string, unknown>[]> => {
    try {
      const raw = await storage.getItem(DIAG_KEY);
      if (!raw) return [];
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? (parsed as Record<string, unknown>[]) : [];
    } catch {
      return [];
    }
  },
  clearPersisted: async (): Promise<void> => {
    try {
      await storage.removeItem(DIAG_KEY);
    } catch {
      // ignore
    }
  },
};

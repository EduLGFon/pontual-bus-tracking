// First-party diagnostics upload. Mirrors app/lib/core/diagnostics/diagnostics_uploader.dart.
import { API_BASE_URL, APP_VERSION } from "../config/env";
import { Log } from "../logging/log";
import * as tokenStore from "../../data/prefs/tokenStore";

export class DiagnosticsUploader {
  async uploadIfOptedIn(optIn: boolean): Promise<void> {
    if (!optIn) return;
    const records = await Log.readPersisted();
    if (records.length === 0) return;
    const token = await tokenStore.readToken();
    const mapped = records.map((r) => ({
      l: (r["l"] as string) ?? "w",
      m: String(r["m"] ?? ""),
      c: r["c"] != null ? String(r["c"]) : undefined,
      t: r["t"],
    }));
    const body = {
      v: 1,
      app: "pontual",
      build: APP_VERSION,
      platform: "rn",
      os: "unknown",
      records: mapped,
      optIn: true,
    };
    try {
      const res = await fetch(`${API_BASE_URL}/v1/diagnostics`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify(body),
      });
      if (res.status === 204 || res.status === 200) {
        await Log.clearPersisted();
      }
    } catch {
      // Keep persisted logs for next attempt.
    }
  }
}

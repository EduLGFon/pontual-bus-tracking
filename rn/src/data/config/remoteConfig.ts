// Remote config (config.json). Mirrors app/lib/data/config/remote_config.dart.
import { STATIC_BASE_URL, APP_VERSION } from "../../core/config/env";
import * as storage from "../prefs/storage";
import { RemoteConfigSchema, type RemoteConfig } from "../api/dto";

const CONFIG_KEY = "remote_config";
const CHECK_KEY = "remote_config_check_ms";
const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;

const BUNDLED_DEFAULT: RemoteConfig = {
  min_app_version: "0.1.0",
  maintenance: false,
  message_pt: "",
  consent_version: 2,
  tile_url: "",
};

export function updateRequired(version: string, min: string): boolean {
  const parts = (v: string) => v.split(".").map((e) => Number(e) || 0);
  const have = parts(version);
  const need = parts(min);
  for (let i = 0; i < 3; i++) {
    const h = i < have.length ? have[i] : 0;
    const n = i < need.length ? need[i] : 0;
    if (h !== n) return h < n;
  }
  return false;
}

export const remoteConfigRepo = {
  async current(): Promise<RemoteConfig> {
    const cached = await storage.getItem(CONFIG_KEY);
    if (cached) {
      try {
        const parsed = RemoteConfigSchema.safeParse(JSON.parse(cached));
        if (parsed.success) {
          const cfg = parsed.data;
          if (cfg.consent_version < BUNDLED_DEFAULT.consent_version) {
            return { ...cfg, consent_version: BUNDLED_DEFAULT.consent_version };
          }
          return cfg;
        }
      } catch {}
    }
    return { ...BUNDLED_DEFAULT, min_app_version: APP_VERSION >= "0.1.0" ? BUNDLED_DEFAULT.min_app_version : BUNDLED_DEFAULT.min_app_version };
  },
  async refresh(force = false): Promise<boolean> {
    const last = Number((await storage.getItem(CHECK_KEY)) ?? "0");
    const now = Date.now();
    if (!force && now - last < CHECK_INTERVAL_MS) return false;
    await storage.setItem(CHECK_KEY, String(now));
    try {
      const res = await fetch(`${STATIC_BASE_URL}/config.json`);
      if (!res.ok) return false;
      const json = await res.json();
      const parsed = RemoteConfigSchema.safeParse(json);
      if (!parsed.success) return false;
      await storage.setItem(CONFIG_KEY, JSON.stringify(parsed.data));
      return parsed.data.maintenance;
    } catch {
      return false;
    }
  },
};

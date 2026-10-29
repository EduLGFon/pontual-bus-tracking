// Static data (offline-first). Mirrors app/lib/data/static_data/static_data.dart (simplified).
import AsyncStorage from "@react-native-async-storage/async-storage";
import { STATIC_BASE_URL } from "../../core/config/env";

export interface StaticLine {
  schema: number;
  id: number;
  code: string;
  short: string;
  name: string;
  terminals: string[];
  area_tags: string[];
  is_active: boolean;
  pilot: boolean;
  schedules: { day_type: string; origin: string; times: string[] }[];
  source_ids: string[];
  verified_at: string;
}

const LINES_KEY = "static_lines";
const MANIFEST_KEY = "static_manifest";
const LAST_CHECK_KEY = "static_last_check_ms";
const CHECK_INTERVAL = 24 * 60 * 60 * 1000;

// Bundled fallback (Metro resolves at build time).
const bundledLines: StaticLine[] = require("../../../assets/data/lines.json");
const bundledManifest = require("../../../assets/data/manifest.json");

export const staticData = {
  async currentLines(): Promise<StaticLine[]> {
    try {
      const cached = await AsyncStorage.getItem(LINES_KEY);
      if (cached) {
        const parsed = JSON.parse(cached) as StaticLine[];
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch {}
    return bundledLines;
  },
  async manifest(): Promise<any> {
    try {
      const cached = await AsyncStorage.getItem(MANIFEST_KEY);
      if (cached) return JSON.parse(cached);
    } catch {}
    return bundledManifest;
  },
  async refresh(): Promise<boolean> {
    const last = Number((await AsyncStorage.getItem(LAST_CHECK_KEY)) ?? "0");
    const now = Date.now();
    if (now - last < CHECK_INTERVAL) return false;
    await AsyncStorage.setItem(LAST_CHECK_KEY, String(now));
    try {
      const res = await fetch(`${STATIC_BASE_URL}/manifest.json`);
      if (!res.ok) return false;
      const manifest = await res.json();
      const linesFile = manifest?.lines;
      if (!linesFile) return false;
      const linesRes = await fetch(`${STATIC_BASE_URL}/${linesFile}`);
      if (!linesRes.ok) return false;
      const lines = await linesRes.json();
      if (!Array.isArray(lines)) return false;
      await AsyncStorage.setItem(LINES_KEY, JSON.stringify(lines));
      await AsyncStorage.setItem(MANIFEST_KEY, JSON.stringify(manifest));
      return true;
    } catch {
      return false;
    }
  },
};

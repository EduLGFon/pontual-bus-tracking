// Static data repository (offline-first). Mirrors app/lib/data/static_data/static_data.dart.
import AsyncStorage from "@react-native-async-storage/async-storage";
import { STATIC_BASE_URL } from "../../core/config/env";
import { decodePolyline } from "../../core/geo/geo";

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

export interface StopPoint {
  id: string;
  lat: number;
  lng: number;
  name?: string | null;
}

const LINES_PREFIX = "static_lines_";
const STOPS_PREFIX = "static_stops_";
const ROUTES_PREFIX = "static_routes_";
const MANIFEST_KEY = "static_manifest";
const MANIFEST_ETAG_KEY = "static_manifest_etag";
const LAST_CHECK_KEY = "static_last_check_ms";
const CHECK_INTERVAL = 24 * 60 * 60 * 1000;

const bundledManifest = require("../../../assets/data/manifest.json");
const bundledLines: StaticLine[] = require("../../../assets/data/lines.json");

function headerOf(headers: Headers, name: string): string | null {
  // fetch Response headers
  return headers.get(name);
}

async function parseLines(text: string): Promise<StaticLine[]> {
  const raw = JSON.parse(text);
  if (!Array.isArray(raw)) return [];
  return raw as StaticLine[];
}

async function parseStops(text: string): Promise<StopPoint[]> {
  const raw = JSON.parse(text);
  if (!Array.isArray(raw)) return [];
  return raw as StopPoint[];
}

export const staticData = {
  async currentLines(): Promise<StaticLine[]> {
    try {
      const manifestStr = await AsyncStorage.getItem(MANIFEST_KEY);
      if (manifestStr) {
        const manifest = JSON.parse(manifestStr);
        const version = manifest?.data_version;
        if (version) {
          const linesStr = await AsyncStorage.getItem(`${LINES_PREFIX}${version}`);
          if (linesStr) {
            const parsed = await parseLines(linesStr);
            if (parsed.length > 0) return parsed;
          }
        }
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
  async stops(): Promise<StopPoint[]> {
    try {
      const manifestStr = await AsyncStorage.getItem(MANIFEST_KEY);
      if (manifestStr) {
        const manifest = JSON.parse(manifestStr);
        const name = manifest?.stops;
        if (name) {
          const stopsStr = await AsyncStorage.getItem(`${STOPS_PREFIX}${name}`);
          if (stopsStr) return await parseStops(stopsStr);
        }
      }
    } catch {}
    return [];
  },
  async route(code: string): Promise<{ lat: number; lng: number }[]> {
    // bundled routes empty in RN; cache/network only
    try {
      const manifestStr = await AsyncStorage.getItem(MANIFEST_KEY);
      if (manifestStr) {
        const manifest = JSON.parse(manifestStr);
        const routes = manifest?.routes as Record<string, string> | undefined;
        const name = routes?.[code];
        if (name) {
          let body = await AsyncStorage.getItem(`${ROUTES_PREFIX}${name}`);
          if (!body) {
            try {
              const res = await fetch(`${STATIC_BASE_URL}/${name}`);
              if (res.ok) {
                body = await res.text();
                if (body) await AsyncStorage.setItem(`${ROUTES_PREFIX}${name}`, body);
              }
            } catch {}
          }
          if (body) {
            const json = JSON.parse(body);
            const poly = json?.polyline as string;
            if (poly) {
              return decodePolyline(poly).map((p) => ({ lat: p.lat, lng: p.lng }));
            }
          }
        }
      }
    } catch {}
    return [];
  },
  async refresh(): Promise<boolean> {
    const last = Number((await AsyncStorage.getItem(LAST_CHECK_KEY)) ?? "0");
    const now = Date.now();
    if (now - last < CHECK_INTERVAL) return false;
    await AsyncStorage.setItem(LAST_CHECK_KEY, String(now));
    try {
      const etag = await AsyncStorage.getItem(MANIFEST_ETAG_KEY);
      const headers: Record<string, string> = {};
      if (etag) headers["if-none-match"] = etag;
      const res = await fetch(`${STATIC_BASE_URL}/manifest.json`, { headers });
      if (res.status === 304) return false;
      if (!res.ok) return false;
      const remote = await res.json();
      const version = remote?.data_version;
      const linesName = remote?.lines;
      if (!version || !linesName) return false;

      // current version
      let current = "";
      try {
        const m = await AsyncStorage.getItem(MANIFEST_KEY);
        if (m) current = JSON.parse(m)?.data_version ?? "";
      } catch {}
      if (!current) {
        try {
          current = bundledManifest?.data_version ?? "";
        } catch {}
      }
      if (version === current) return false;

      const linesRes = await fetch(`${STATIC_BASE_URL}/${linesName}`);
      if (!linesRes.ok) return false;
      const linesText = await linesRes.text();
      const parsed = await parseLines(linesText);
      if (parsed.length === 0) return false;

      // stops optional
      let stopsName: string | null = null;
      let stopsBody: string | null = null;
      const remoteStops = remote?.stops as string | null | undefined;
      if (remoteStops) {
        try {
          const sr = await fetch(`${STATIC_BASE_URL}/${remoteStops}`);
          if (sr.ok) {
            const text = await sr.text();
            parseStops(text); // validate
            stopsName = remoteStops;
            stopsBody = text;
          }
        } catch {}
      }

      // atomic swap
      await AsyncStorage.setItem(`${LINES_PREFIX}${version}`, linesText);
      if (stopsName && stopsBody) {
        await AsyncStorage.setItem(`${STOPS_PREFIX}${stopsName}`, stopsBody);
      }
      await AsyncStorage.setItem(MANIFEST_KEY, JSON.stringify(remote));
      const newEtag = headerOf(res.headers, "etag");
      if (newEtag) await AsyncStorage.setItem(MANIFEST_ETAG_KEY, newEtag);

      // evict
      const keys = await AsyncStorage.getAllKeys();
      for (const k of keys) {
        if (k.startsWith(LINES_PREFIX) && k !== `${LINES_PREFIX}${version}`) {
          await AsyncStorage.removeItem(k);
        }
        if (stopsName && k.startsWith(STOPS_PREFIX) && k !== `${STOPS_PREFIX}${stopsName}`) {
          await AsyncStorage.removeItem(k);
        }
      }
      return true;
    } catch {
      return false;
    }
  },
};

export type StaticData = typeof staticData;

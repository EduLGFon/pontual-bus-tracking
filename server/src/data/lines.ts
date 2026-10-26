// Line resolver. Production data comes from the built static bundle in
// DATA_DIR; tests inject a fake resolver. Line ids are stable and never
// reused; removal means is_active false.
import { decodePolyline, type RouteShape, routeShape } from "../domain/geo.ts";

export interface LineRecord {
  id: number;
  code?: string;
  isActive: boolean;
  route: RouteShape | null;
}

export type LineResolver = (id: number) => LineRecord | null;

/** Registry resolver for tests and early wiring. */
export function registryResolver(lines: LineRecord[]): LineResolver {
  const byId = new Map(lines.map((l) => [l.id, l]));
  return (id: number) => byId.get(id) ?? null;
}

interface BundleLine {
  id?: unknown;
  code?: unknown;
  is_active?: unknown;
}

/**
 * Load the built bundle from DATA_DIR (manifest, lines file, route files).
 * Returns an empty list when the bundle is absent. Throws on corrupt
 * bundles. Route geometry lands here from the T17 tool output.
 */
export async function loadLinesFromDir(dataDir: string): Promise<LineRecord[]> {
  let manifestText: string;
  try {
    manifestText = await Deno.readTextFile(`${dataDir}/manifest.json`);
  } catch {
    return [];
  }
  const manifest = JSON.parse(manifestText) as {
    lines?: unknown;
    routes?: unknown;
  };
  if (typeof manifest.lines !== "string" || manifest.lines.includes("..")) {
    throw new Error("bad bundle manifest");
  }
  const linesText = await Deno.readTextFile(`${dataDir}/${manifest.lines}`);
  const lines = JSON.parse(linesText) as BundleLine[];
  if (!Array.isArray(lines)) throw new Error("bad bundle lines");
  const routes = (manifest.routes ?? {}) as Record<string, unknown>;
  const byCode = new Map<string, RouteShape>();
  for (const [code, path] of Object.entries(routes)) {
    if (typeof path !== "string" || path.includes("..")) {
      throw new Error(`bad route path for ${code}`);
    }
    const file = JSON.parse(
      await Deno.readTextFile(`${dataDir}/${path}`),
    ) as { polyline?: unknown };
    if (typeof file.polyline !== "string") {
      throw new Error(`bad route file for ${code}`);
    }
    byCode.set(code, routeShape(decodePolyline(file.polyline, 5)));
  }
  return lines.map((l) => ({
    id: Number(l.id),
    code: String(l.code ?? l.id),
    isActive: l.is_active === true,
    route: byCode.get(String(l.code)) ?? null,
  }));
}

// Stop registry for report target validation. Production data comes from
// the built static bundle in DATA_DIR; tests inject a resolver. Stop ids
// are public infrastructure identifiers, never people.
import { isValidStopId } from "../domain/reports.ts";

export type StopResolver = (id: string) => boolean;

/**
 * Registry resolver for tests and early wiring. When no stop data is
 * loaded (local seed, no bundle), well-formed ids pass so local testing
 * still works; production bundles validate the exact set.
 */
export function registryStopResolver(ids: string[]): StopResolver {
  if (ids.length === 0) {
    return (id: string) => isValidStopId(id);
  }
  const set = new Set(ids);
  return (id: string) => set.has(id);
}

interface Manifest {
  stops?: unknown;
}

/**
 * Load stop ids from the built bundle. Returns an empty list when the
 * bundle is absent or names no stops. Throws on a corrupt path.
 */
export async function loadStopsFromDir(dataDir: string): Promise<string[]> {
  let manifestText: string;
  try {
    manifestText = await Deno.readTextFile(`${dataDir}/manifest.json`);
  } catch {
    return [];
  }
  const manifest = JSON.parse(manifestText) as Manifest;
  if (manifest.stops === undefined || manifest.stops === null) return [];
  if (typeof manifest.stops !== "string" || manifest.stops.includes("..")) {
    throw new Error("bad bundle stops path");
  }
  const text = await Deno.readTextFile(`${dataDir}/${manifest.stops}`);
  const rows = JSON.parse(text) as { id?: unknown }[];
  if (!Array.isArray(rows)) throw new Error("bad bundle stops");
  return rows
    .map((row) => row.id)
    .filter((id): id is string => typeof id === "string");
}

// Offline map build tool. Downloads nothing in bulk from tile servers:
// it extracts a city bbox from the Protomaps daily planet build (a data
// file, not a tile endpoint) with the pmtiles CLI, then verifies and
// reports the size. See docs/maps.md.
// Run from tools/: deno task map-bbox | map-extract | map-verify | map-test.

const ROOT = new URL("../../", import.meta.url);
const MAP_DIR = new URL("./", import.meta.url);
const BBOX_URL = new URL("bbox.json", MAP_DIR);
const ROUTES_DIR = new URL("data/routes/", ROOT);

interface BboxFile {
  municipality: { south: number; north: number; west: number; east: number };
  extract_bbox: {
    min_lon: number;
    min_lat: number;
    max_lon: number;
    max_lat: number;
  };
  app_bounds: { south: number; north: number; west: number; east: number };
  protomaps_build: string;
  protomaps_url_pattern: string;
  pmtiles_cli: string;
}

export async function loadBbox(): Promise<BboxFile> {
  return JSON.parse(await Deno.readTextFile(BBOX_URL)) as BboxFile;
}

/** Result of the offline coverage check, used by tests and docs. */
export interface CoverageCheck {
  municipalityInsideExtract: boolean;
  appBoundsInsideExtract: boolean;
  routeFiles: number;
  routesInsideExtract: boolean;
  notes: string[];
}

/** Checks that the extract bbox covers the municipality, the app pan
 * bounds and every committed route trace. Pure except for file reads. */
export async function checkCoverage(bbox: BboxFile): Promise<CoverageCheck> {
  const notes: string[] = [];
  const e = bbox.extract_bbox;
  const m = bbox.municipality;
  const a = bbox.app_bounds;
  const inside = (south: number, north: number, west: number, east: number) =>
    west >= e.min_lon && east <= e.max_lon && south >= e.min_lat &&
    north <= e.max_lat;
  const municipalityInsideExtract = inside(m.south, m.north, m.west, m.east);
  if (!municipalityInsideExtract) {
    notes.push("municipality exceeds extract bbox");
  }
  const appBoundsInsideExtract = inside(a.south, a.north, a.west, a.east);
  if (!appBoundsInsideExtract) notes.push("app mapBounds exceeds extract bbox");
  // App pan bounds are intentionally tighter than the extract: the buffer
  // around them keeps context visible at the edges while panning.
  let routeFiles = 0;
  let routesInsideExtract = true;
  try {
    for await (const entry of Deno.readDir(ROUTES_DIR)) {
      if (!entry.isFile || !entry.name.endsWith(".geojson")) continue;
      routeFiles++;
      const text = await Deno.readTextFile(
        new URL(entry.name, ROUTES_DIR),
      );
      const geo = JSON.parse(text) as unknown;
      const pts = geometryCoords(geo);
      for (const [lon, lat] of pts) {
        if (
          lon < e.min_lon || lon > e.max_lon || lat < e.min_lat ||
          lat > e.max_lat
        ) {
          routesInsideExtract = false;
          notes.push(`${entry.name}: point outside extract bbox`);
          break;
        }
      }
    }
  } catch {
    notes.push("routes dir unreadable, skipped route check");
  }
  if (routeFiles === 0) {
    notes.push("no route traces committed yet, check reruns when they land");
  }
  return {
    municipalityInsideExtract,
    appBoundsInsideExtract,
    routeFiles,
    routesInsideExtract,
    notes,
  };
}

/** Collects every position from a GeoJSON geometry, feature or
 * collection. Unknown shapes yield no points (caller notes empty sets). */
export function geometryCoords(node: unknown): Array<[number, number]> {
  if (typeof node !== "object" || node === null) return [];
  const obj = node as Record<string, unknown>;
  if ("coordinates" in obj) return flattenCoords(obj.coordinates);
  if ("geometry" in obj) return geometryCoords(obj.geometry);
  if (Array.isArray(obj.features)) {
    return obj.features.flatMap((f) => geometryCoords(f));
  }
  return [];
}

function flattenCoords(node: unknown): Array<[number, number]> {
  if (!Array.isArray(node)) return [];
  if (typeof node[0] === "number" && typeof node[1] === "number") {
    return [[node[0] as number, node[1] as number]];
  }
  const out: Array<[number, number]> = [];
  for (const child of node) out.push(...flattenCoords(child));
  return out;
}

/** Exact pmtiles extract command for the pinned build. Printed by
 * map-extract and run when the pmtiles CLI is on PATH. */
export function extractCommand(
  bbox: BboxFile,
  out: string,
  maxzoom?: number,
): string[] {
  const e = bbox.extract_bbox;
  const url = `https://build.protomaps.com/${bbox.protomaps_build}.pmtiles`;
  const args = [
    "pmtiles",
    "extract",
    url,
    out,
    `--bbox=${e.min_lon},${e.min_lat},${e.max_lon},${e.max_lat}`,
  ];
  if (maxzoom !== undefined) args.push(`--maxzoom=${maxzoom}`);
  return args;
}

async function main(): Promise<void> {
  const cmd = Deno.args[0] ?? "bbox";
  const bbox = await loadBbox();
  if (cmd === "bbox") {
    const c = await checkCoverage(bbox);
    console.log(
      JSON.stringify({ extract_bbox: bbox.extract_bbox, ...c }, null, 2),
    );
    if (!c.municipalityInsideExtract || !c.routesInsideExtract) Deno.exit(1);
  } else if (cmd === "extract") {
    const out = Deno.args[1] ?? "sao_mateus.pmtiles";
    const maxzoom = Deno.args[2] !== undefined
      ? Number(Deno.args[2])
      : undefined;
    const args = extractCommand(bbox, out, maxzoom);
    console.log(args.join(" "));
    const proc = new Deno.Command(args[0], {
      args: args.slice(1),
      stdout: "inherit",
      stderr: "inherit",
    });
    const status = await proc.output();
    if (!status.success) Deno.exit(status.code);
    const stat = await Deno.stat(out);
    console.log(`wrote ${out}: ${(stat.size / 1048576).toFixed(1)} MB`);
  } else if (cmd === "verify") {
    const file = Deno.args[1] ?? "sao_mateus.pmtiles";
    for (
      const sub of [["pmtiles", "verify", file], ["pmtiles", "show", file]]
    ) {
      const proc = new Deno.Command(sub[0], {
        args: sub.slice(1),
        stdout: "inherit",
        stderr: "inherit",
      });
      const status = await proc.output();
      if (!status.success) Deno.exit(status.code);
    }
    const stat = await Deno.stat(file);
    console.log(`size: ${(stat.size / 1048576).toFixed(1)} MB`);
  } else {
    console.log(
      "usage: map/main.ts [bbox|extract [out] [maxzoom]|verify [file]]",
    );
    Deno.exit(2);
  }
}

if (import.meta.main) await main();

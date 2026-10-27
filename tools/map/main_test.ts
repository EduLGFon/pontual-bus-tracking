// Coverage checks for the offline map extract bbox.
import { assert, assertEquals } from "@std/assert";
import {
  checkCoverage,
  extractCommand,
  geometryCoords,
  loadBbox,
  missingBinHelp,
} from "./main.ts";

Deno.test("extract bbox covers municipality and app bounds", async () => {
  const bbox = await loadBbox();
  const c = await checkCoverage(bbox);
  assert(c.municipalityInsideExtract, c.notes.join("; "));
  assert(c.appBoundsInsideExtract, c.notes.join("; "));
  assert(c.routesInsideExtract, c.notes.join("; "));
});

Deno.test("geometryCoords reads features and collections", () => {
  assertEquals(
    geometryCoords({
      type: "LineString",
      coordinates: [[-40, -19], [-39.6, -18.5]],
    }),
    [[-40, -19], [-39.6, -18.5]],
  );
  assertEquals(
    geometryCoords({
      type: "FeatureCollection",
      features: [{
        type: "Feature",
        geometry: { type: "Point", coordinates: [-40, -19] },
      }],
    }),
    [[-40, -19]],
  );
  assertEquals(geometryCoords({ type: "Empty" }), []);
});

Deno.test("extract command uses bbox order lon,lat and pinned build", async () => {
  const bbox = await loadBbox();
  const cmd = extractCommand(bbox, "out.pmtiles");
  assertEquals(cmd.slice(0, 3), [
    "pmtiles",
    "extract",
    "https://build.protomaps.com/20261026.pmtiles",
  ]);
  assert(cmd.some((a) => a.startsWith("--bbox=-40.46,-19.2,-39.5,-18.39")));
  const capped = extractCommand(bbox, "out.pmtiles", 14);
  assert(capped.includes("--maxzoom=14"));
});

Deno.test("missing binary help names the binary and the manual command", () => {
  const help = missingBinHelp("pmtiles", "1.31.2", [
    "pmtiles",
    "verify",
    "f.pmtiles",
  ]);
  assert(help.includes('tried "pmtiles"'));
  assert(help.includes("1.31.2"));
  assert(help.includes("PMTILES_BIN"));
  assert(help.includes("pmtiles verify f.pmtiles"));
});

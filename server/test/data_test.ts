// Bundle loader tests: missing dir yields empty, built bundle loads.
import { assertEquals } from "@std/assert";
import { loadLinesFromDir, registryResolver } from "../src/data/lines.ts";

Deno.test("missing bundle yields empty registry", async () => {
  const dir = await Deno.makeTempDir();
  try {
    assertEquals(await loadLinesFromDir(dir), []);
    assertEquals(registryResolver([])(7), null);
  } finally {
    await Deno.remove(dir, { recursive: true });
  }
});

Deno.test("built bundle loads lines", async () => {
  const dir = await Deno.makeTempDir();
  try {
    const lines = JSON.stringify([{ id: 7, code: "seven", is_active: true }]);
    await Deno.writeTextFile(`${dir}/lines.abc123def456.json`, lines);
    await Deno.writeTextFile(
      `${dir}/manifest.json`,
      JSON.stringify({ lines: "lines.abc123def456.json", routes: {} }),
    );
    const loaded = await loadLinesFromDir(dir);
    assertEquals(loaded, [
      { id: 7, code: "seven", isActive: true, route: null },
    ]);
  } finally {
    await Deno.remove(dir, { recursive: true });
  }
});

Deno.test("bundle routes decode to geometry", async () => {
  const dir = await Deno.makeTempDir();
  try {
    await Deno.writeTextFile(
      `${dir}/lines.abc123def456.json`,
      JSON.stringify([{ id: 7, code: "seven", is_active: true }]),
    );
    // Polyline "_p~iF~ps|U" decodes to (38.5,-120.2) precision 5.
    await Deno.writeTextFile(
      `${dir}/r.json`,
      JSON.stringify({ code: "seven", polyline: "_p~iF~ps|U" }),
    );
    await Deno.writeTextFile(
      `${dir}/manifest.json`,
      JSON.stringify({
        lines: "lines.abc123def456.json",
        routes: { seven: "r.json" },
      }),
    );
    const loaded = await loadLinesFromDir(dir);
    assertEquals(loaded.length, 1);
    assertEquals(loaded[0].route?.pts.length, 1);
    // Single-point route: the box collapses to the decoded fix.
    assertEquals(loaded[0].route?.minLat, 38.5);
    assertEquals(loaded[0].route?.maxLat, 38.5);
    assertEquals(loaded[0].route?.minLng, -120.2);
    assertEquals(loaded[0].route?.maxLng, -120.2);
  } finally {
    await Deno.remove(dir, { recursive: true });
  }
});

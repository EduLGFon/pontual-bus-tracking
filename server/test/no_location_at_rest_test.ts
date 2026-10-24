// AC22: no location at rest. Migrations must contain no location-like
// columns. See PLAN.md 6.4 and 12.6 AC22.
import { assertEquals } from "@std/assert";

const FORBIDDEN = [
  "lat",
  "lng",
  "latitude",
  "longitude",
  "coord",
  "speed",
  "heading",
  "accuracy",
  "battery",
  "trip_",
  "_trip",
  "ping",
  "fix",
];

Deno.test("migrations contain no location-like columns", async () => {
  const dir = new URL("../db/migrations/", import.meta.url);
  let found = 0;
  for await (const entry of Deno.readDir(dir)) {
    if (!entry.name.endsWith(".sql")) continue;
    found += 1;
    const text = await Deno.readTextFile(new URL(entry.name, dir));
    const lower = text.toLowerCase();
    const lines = lower.split(/\r?\n/);
    let currentTable = "";
    for (const line of lines) {
      const tm = line.match(/create table (?:if not exists )?(\w+)/);
      if (tm) currentTable = tm[1];
      for (const word of FORBIDDEN) {
        // Aggregate stop centroids are the one permitted location at rest
        // (see docs/data-learning.md section 7); they live only in
        // learned_stops and are not individual locations.
        if (
          (word === "lat" || word === "lng") &&
          currentTable === "learned_stops"
        ) {
          continue;
        }
        const re = new RegExp(
          `\\b${word}[a-z_]*\\s+(double|real|numeric|float|int|smallint|boolean|bytea|jsonb?)\\b`,
        );
        const hit = line.match(re);
        assertEquals(
          hit,
          null,
          `${entry.name} contains location-like column: ${hit?.[0]}`,
        );
      }
    }
  }
  assertEquals(found >= 1, true, "expected at least one migration");
});
// Data tool tests: schema-driven structure plus semantic rules.
import { assert, assertEquals, assertThrows } from "@std/assert";
import {
  buildBundle,
  checkSemantics,
  checkStopsSemantics,
  checkStructure,
  readLineFiles,
} from "./main.ts";

const SCHEMA = {
  required: ["schema", "id", "code"],
  additionalProperties: false,
  properties: {
    schema: { type: "integer", const: 1 },
    id: { type: "integer", minimum: 1 },
    code: { type: "string", pattern: "^[a-z0-9-]{2,40}$" },
  },
};

Deno.test("structure rejects missing and unknown keys", () => {
  assertThrows(
    () => checkStructure("x.json", SCHEMA, { schema: 1, id: 1 }),
    Error,
    "missing",
  );
  assertThrows(
    () =>
      checkStructure("x.json", SCHEMA, {
        schema: 1,
        id: 1,
        code: "a1",
        bogus: 2,
      }),
    Error,
    "unknown key",
  );
  checkStructure("x.json", SCHEMA, { schema: 1, id: 1, code: "a1" });
});

Deno.test("semantics rejects duplicates and unsorted times", () => {
  const line = (id: number, code: string, times: string[]) => ({
    path: `${code}.json`,
    bytes: 10,
    data: {
      id,
      code,
      short: code.slice(0, 2),
      schedules: [{ day_type: "weekday", origin: "A", times }],
    },
  });
  assertThrows(
    () => checkSemantics([line(1, "a1", ["05:30"]), line(1, "a2", ["05:30"])]),
    Error,
    "duplicate id",
  );
  assertThrows(
    () => checkSemantics([line(1, "a1", ["06:10", "05:30"])]),
    Error,
    "unsorted",
  );
  assertThrows(
    () => checkSemantics([line(1, "a1", ["25:00"])]),
    Error,
    "bad time",
  );
  checkSemantics([line(1, "a1", ["05:30", "06:10"])]);
  assertEquals(typeof checkSemantics, "function");
  assert(true);
});

Deno.test("stops semantics: unique sorted ids inside the area", () => {
  const stop = (id: string, lat = -18.72, lng = -39.85) => ({
    id,
    name: null,
    lat,
    lng,
    src: "osm",
  });
  assertThrows(
    () => checkStopsSemantics([stop("s1"), stop("s1")]),
    Error,
    "duplicate id",
  );
  assertThrows(
    () => checkStopsSemantics([stop("s2"), stop("s1")]),
    Error,
    "sorted",
  );
  assertThrows(
    () => checkStopsSemantics([stop("s1", -18.0, -39.85)]),
    Error,
    "outside",
  );
  checkStopsSemantics([stop("s1"), stop("s2")]);
});

Deno.test("bundle writes headers with revalidation rules", async () => {
  const files = await readLineFiles();
  checkSemantics(files);
  await buildBundle(files);
  const headers = await Deno.readTextFile(
    new URL("../../build/_headers", import.meta.url),
  );
  assert(headers.includes("/data/manifest.json"));
  assert(headers.includes("/data/config.json"));
  assert(headers.includes("no-cache"));
  assert(headers.includes("Content-Security-Policy"));
});

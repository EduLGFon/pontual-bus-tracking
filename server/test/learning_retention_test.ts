// Retention follows the learned stop lifecycle. Histograms are cumulative and
// have no per-trip timestamps, so the purge must not delete stats while their
// bins survive. See DECISIONS.md#D109.
import { assert, assertEquals } from "@std/assert";
import type { Sql } from "../src/db/client.ts";
import { runPurgeLearning } from "../src/jobs/jobs.ts";

function recordingSql(): { sql: Sql; queries: string[] } {
  const queries: string[] = [];
  const sql = ((strings: TemplateStringsArray) => {
    queries.push(strings.join("?"));
    return Promise.resolve([]);
  }) as unknown as Sql;
  return { sql, queries };
}

Deno.test("learning purge deactivates and deletes dormant stops only", async () => {
  const { sql, queries } = recordingSql();
  await runPurgeLearning(sql, new Date("2026-11-12T00:00:00Z"));
  assertEquals(queries.length, 3);
  assert(queries[0].includes("update learned_stops set active = false"));
  assert(queries[1].includes("delete from learned_stops"));
  assert(queries[2].includes("delete from learned_routes"));
  assert(!queries.some((q) => q.includes("stop_dwell_stats")));
  assert(!queries.some((q) => q.includes("segment_stats")));
});

import { assertEquals } from "@std/assert";
import { snapshot } from "../src/observability/metrics.ts";
import * as m from "../src/observability/metrics.ts";

Deno.test("metrics: new learning drop counters exist and increment", () => {
  const before = snapshot().learningTripsIneligibleTotal;
  m.recordLearningTripIneligible();
  assertEquals(snapshot().learningTripsIneligibleTotal, before + 1);
});

Deno.test("metrics: flush failed counter increments", () => {
  const before = snapshot().learningFlushesFailedTotal;
  m.recordLearningFlushFailed();
  assertEquals(snapshot().learningFlushesFailedTotal, before + 1);
});

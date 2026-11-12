import { assertEquals } from "@std/assert";
import {
  recordLearningFlushFailed,
  recordLearningTripIneligible,
  recordPingRateLimited,
  snapshot,
} from "../src/observability/metrics.ts";

Deno.test("metrics: new learning drop counters exist and increment", () => {
  const before = snapshot().learningTripsIneligibleTotal;
  recordLearningTripIneligible();
  assertEquals(snapshot().learningTripsIneligibleTotal, before + 1);
});

Deno.test("metrics: flush failed counter increments", () => {
  const before = snapshot().learningFlushesFailedTotal;
  recordLearningFlushFailed();
  assertEquals(snapshot().learningFlushesFailedTotal, before + 1);
});

Deno.test("ping rate-limited counter increments", () => {
  const before = snapshot().pingsRateLimitedTotal;
  recordPingRateLimited();
  const after = snapshot().pingsRateLimitedTotal;
  assertEquals(after, before + 1);
});

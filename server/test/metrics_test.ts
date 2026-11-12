import { assertEquals } from "@std/assert";
import {
  recordPingRateLimited,
  snapshot,
} from "../src/observability/metrics.ts";

Deno.test("ping rate-limited counter increments", () => {
  const before = snapshot().pingsRateLimitedTotal;
  recordPingRateLimited();
  const after = snapshot().pingsRateLimitedTotal;
  assertEquals(after, before + 1);
});

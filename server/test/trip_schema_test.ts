// Trip start schema: the optional synthetic flag is additive and defaults to
// false. It only suppresses learning for that trip. See DECISIONS.md#D110.
import { assert } from "@std/assert";
import * as v from "@valibot/valibot";
import { TripStartBody } from "../src/http/tripSchemas.ts";

const base = {
  line: 7,
  lat: -18.72,
  lng: -39.85,
  acc: 10,
  bat: 80,
  chg: false,
};

Deno.test("trip start accepts an optional synthetic flag", () => {
  assert(v.safeParse(TripStartBody, base).success);
  assert(v.safeParse(TripStartBody, { ...base, synthetic: true }).success);
  assert(v.safeParse(TripStartBody, { ...base, synthetic: false }).success);
  assert(!v.safeParse(TripStartBody, { ...base, synthetic: "yes" }).success);
});

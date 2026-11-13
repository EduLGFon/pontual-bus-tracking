// Trip request schemas. Strict objects, finite numbers, no ids.
// See ARCHITECTURE.md 6.5. Ping outcomes that end the trip are HTTP 200 with "e".
import * as v from "@valibot/valibot";

const finite = v.pipe(v.number(), v.finite());

/** POST /v1/trip: line plus first fix. No client timestamp (server time). */
export const TripStartBody = v.strictObject({
  line: v.pipe(v.number(), v.integer(), v.minValue(1)),
  lat: finite,
  lng: finite,
  acc: v.pipe(v.number(), v.minValue(0)),
  bat: v.pipe(v.number(), v.integer(), v.minValue(0), v.maxValue(100)),
  chg: v.boolean(),
  resume: v.optional(v.boolean(), false),
  // Client-supplied and untrusted. It can only suppress this trip's
  // contribution to learning; it never grants access or changes live sharing.
  synthetic: v.optional(v.boolean(), false),
});

/** POST /v1/trip/ping: sequence plus fix plus role acknowledgement. */
export const TripPingBody = v.strictObject({
  seq: v.pipe(v.number(), v.integer(), v.minValue(1)),
  lat: finite,
  lng: finite,
  spd: v.pipe(v.number(), v.minValue(0)),
  hdg: v.nullable(v.pipe(v.number(), v.minValue(0), v.maxValue(359))),
  acc: v.pipe(v.number(), v.minValue(0)),
  bat: v.pipe(v.number(), v.integer(), v.minValue(0), v.maxValue(100)),
  chg: v.boolean(),
  role: v.picklist(["L", "F", "W"]),
});

export type TripStart = v.InferOutput<typeof TripStartBody>;
export type TripPing = v.InferOutput<typeof TripPingBody>;

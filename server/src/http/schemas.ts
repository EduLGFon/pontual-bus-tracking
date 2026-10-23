// Strict request schemas. Unknown keys rejected, finite numbers only.
// Every body is parsed here at the boundary; handlers receive typed values.
// See PLAN.md 6.5 and 14.4.
import * as v from "@valibot/valibot";

function strictObject<T extends v.ObjectEntries>(entries: T) {
  return v.strictObject(entries);
}

/** POST /v1/devices takes an empty object. */
export const DevicesBody = strictObject({});

/** POST /v1/consents takes the consent version only. No ids. */
export const ConsentsBody = strictObject({
  version: v.pipe(v.number(), v.integer(), v.minValue(1), v.maxValue(32767)),
});

/**
 * POST /v1/reports. No coordinates, no timestamps, no free text.
 * `area` is a coarse ~150 m grid cell, required for waiting/blocked and
 * forbidden for broken/full; the handler enforces the kind-target rule.
 */
export const ReportBody = strictObject({
  op: v.picklist(["report", "retract"]),
  kind: v.picklist(["waiting", "full", "broken", "blocked"]),
  line: v.pipe(v.number(), v.integer(), v.minValue(1)),
  area: v.optional(v.pipe(v.string(), v.maxLength(40))),
});

/** POST /v1/diagnostics. Redacted bundle, no PII. */
export const DiagnosticsBody = strictObject({
  v: v.pipe(v.number(), v.integer(), v.minValue(1), v.maxValue(32767)),
  app: v.pipe(v.string(), v.maxLength(40)),
  build: v.pipe(v.string(), v.maxLength(40)),
  platform: v.pipe(v.string(), v.maxLength(20)),
  os: v.pipe(v.string(), v.maxLength(60)),
  model: v.optional(v.pipe(v.string(), v.maxLength(60))),
  records: v.pipe(
    v.array(
      strictObject({
        l: v.picklist(["w", "e"]),
        m: v.pipe(v.string(), v.maxLength(200)),
        c: v.optional(v.pipe(v.string(), v.maxLength(200))),
        t: v.optional(v.pipe(v.number(), v.integer())),
      }),
    ),
    v.maxLength(500),
  ),
  crash: v.optional(v.pipe(v.string(), v.maxLength(4000))),
  optIn: v.boolean(),
});

/** Typed diagnostics request. */
export type DiagnosticsRequest = v.InferOutput<typeof DiagnosticsBody>;

export function parseJson<T>(
  schema: v.GenericSchema<T>,
  input: unknown,
): T | null {
  const r = v.safeParse(schema, input);
  return r.success ? r.output : null;
}

/** True for finite numbers only (rejects NaN, Infinity). */
export function isFiniteNumber(n: unknown): n is number {
  return typeof n === "number" && Number.isFinite(n);
}

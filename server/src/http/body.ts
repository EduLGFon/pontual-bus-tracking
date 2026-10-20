// Small strict body reader shared by JSON endpoints. Body limits are per
// route in PLAN.md 6.5; callers pass the cap. Malformed or empty bodies
// stay distinguishable so handlers can answer 400 instead of 500.
export type ParsedBody =
  | { kind: "json"; value: unknown }
  | { kind: "media" }
  | { kind: "empty" };

export async function readJsonBody(
  c: {
    req: { header(n: string): string | undefined; text(): Promise<string> };
  },
  cap = 1024,
): Promise<ParsedBody> {
  const len = c.req.header("content-length");
  const lenNum = len !== undefined ? Number(len) : NaN;
  if (Number.isFinite(lenNum) && lenNum > cap) {
    return { kind: "media" };
  }
  if (!(c.req.header("content-type") ?? "").includes("application/json")) {
    return { kind: "media" };
  }
  try {
    const text = await c.req.text();
    if (text.length > cap) return { kind: "media" };
    if (text.trim() === "") return { kind: "empty" };
    return { kind: "json", value: JSON.parse(text) };
  } catch {
    return { kind: "empty" };
  }
}

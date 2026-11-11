import { assertEquals } from "@std/assert";
import { DiagnosticsBody, parseJson } from "../src/http/schemas.ts";

const base = {
  v: 1,
  app: "pontual",
  build: "0.1.0",
  platform: "web",
  os: "web",
  records: [],
  optIn: true,
};

Deno.test("diagnostics body parses without id", () => {
  const r = parseJson(DiagnosticsBody, base);
  if (r === null) throw new Error("expected parse");
  assertEquals(r.id, undefined);
});

Deno.test("diagnostics body parses with id", () => {
  const r = parseJson(DiagnosticsBody, { ...base, id: "abc-123" });
  if (r === null) throw new Error("expected parse");
  assertEquals(r.id, "abc-123");
});

Deno.test("diagnostics body rejects a 65-char id", () => {
  const r = parseJson(DiagnosticsBody, { ...base, id: "a".repeat(65) });
  assertEquals(r, null);
});

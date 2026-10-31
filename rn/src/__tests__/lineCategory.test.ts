import { categoryFor, lineCategoryLabel } from "../domain/lineCategory";

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(msg);
}

assert(categoryFor({ short: "66", name: "x", terminals: [] }) === "ufes", "ufes");
assert(categoryFor({ short: "999", name: "Linha Guriri", terminals: [] }) === "guriri", "guriri fallback");
assert(lineCategoryLabel("other") === "Outras", "label");

import { categoryFor, lineCategoryLabel } from "../domain/lineCategory";

describe("lineCategory", () => {
  test("ufes and guriri mapping", () => {
    expect(categoryFor({ short: "66", name: "x", terminals: [] })).toBe("ufes");
    expect(categoryFor({ short: "999", name: "Linha Guriri", terminals: [] })).toBe("guriri");
  });
  test("label", () => {
    expect(lineCategoryLabel("other")).toBe("Outras");
  });
});

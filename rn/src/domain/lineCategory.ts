// Line categories. Mirrors app/lib/domain/line_category.dart.
export type LineCategory = "ufes" | "guriri" | "aroeira" | "other";

export const lineCategoryByShort: Record<string, LineCategory> = {
  "66": "ufes",
  "62": "ufes",
  "60": "ufes",
  "64": "ufes",
  "701": "guriri",
  "70": "guriri",
  "23": "guriri",
  "13": "aroeira",
  "10": "aroeira",
};

export function lineCategoryLabel(c: LineCategory): string {
  switch (c) {
    case "ufes":
      return "UFES / IFES";
    case "guriri":
      return "Guriri";
    case "aroeira":
      return "Aroeira";
    case "other":
      return "Outras";
  }
}

export function lineCategoryOrder(c: LineCategory): number {
  switch (c) {
    case "ufes":
      return 0;
    case "guriri":
      return 1;
    case "aroeira":
      return 2;
    case "other":
      return 3;
  }
}

const diacritics: Record<number, string> = {
  0xe0: "a", 0xe1: "a", 0xe2: "a", 0xe3: "a", 0xe4: "a", 0xe5: "a",
  0xe7: "c", 0xe8: "e", 0xe9: "e", 0xea: "e", 0xeb: "e",
  0xec: "i", 0xed: "i", 0xee: "i", 0xef: "i",
  0xf2: "o", 0xf3: "o", 0xf4: "o", 0xf5: "o", 0xf6: "o",
  0xf9: "u", 0xfa: "u", 0xfb: "u", 0xfc: "u",
};

function normalize(input: string): string {
  let out = "";
  for (const ch of input.toLowerCase()) {
    const code = ch.charCodeAt(0);
    out += diacritics[code] ?? ch;
  }
  return out;
}

export function categoryFor(opts: {
  short: string;
  name: string;
  terminals: string[];
  areaTags?: string[];
}): LineCategory {
  const mapped = lineCategoryByShort[opts.short.trim()];
  if (mapped) return mapped;
  const haystack = normalize([opts.name, ...opts.terminals, ...(opts.areaTags ?? [])].join(" "));
  if (haystack.includes("ufes") || haystack.includes("ifes")) return "ufes";
  if (haystack.includes("guriri")) return "guriri";
  if (haystack.includes("aroeira")) return "aroeira";
  return "other";
}

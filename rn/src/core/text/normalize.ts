// Text normalization. Mirrors app/lib/ui/util/search_index.dart normalizeText.
const diacritics: Record<number, string> = {
  0xe0: "a", 0xe1: "a", 0xe2: "a", 0xe3: "a", 0xe4: "a", 0xe5: "a",
  0xe7: "c", 0xe8: "e", 0xe9: "e", 0xea: "e", 0xeb: "e",
  0xec: "i", 0xed: "i", 0xee: "i", 0xef: "i",
  0xf0: "o", 0xf1: "n", 0xf2: "o", 0xf3: "o", 0xf4: "o", 0xf5: "o", 0xf6: "o",
  0xf9: "u", 0xfa: "u", 0xfb: "u", 0xfc: "u",
};

export function normalizeForSearch(input: string): string {
  let out = "";
  for (const ch of input.toLowerCase()) {
    const code = ch.charCodeAt(0);
    out += diacritics[code] ?? ch;
  }
  return out.replace(/\s+/g, " ").trim();
}

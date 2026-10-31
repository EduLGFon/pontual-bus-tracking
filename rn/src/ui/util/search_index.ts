// Search index. Port of app/lib/ui/util/search_index.dart.
import type { LineVM } from "../models/line_vm";

const diacritics: Record<number, string> = {
  0xe0: "a", 0xe1: "a", 0xe2: "a", 0xe3: "a", 0xe4: "a", 0xe5: "a",
  0xe7: "c", 0xe8: "e", 0xe9: "e", 0xea: "e", 0xeb: "e",
  0xec: "i", 0xed: "i", 0xee: "i", 0xef: "i", 0xf0: "o", 0xf1: "n",
  0xf2: "o", 0xf3: "o", 0xf4: "o", 0xf5: "o", 0xf6: "o",
  0xf9: "u", 0xfa: "u", 0xfb: "u", 0xfc: "u",
};

export function normalizeText(input: string): string {
  let out = "";
  for (const ch of input.toLowerCase()) {
    const code = ch.codePointAt(0) ?? 0;
    out += diacritics[code] ?? ch;
  }
  return out.replace(/\s+/g, " ").trim();
}

export interface LineIndex {
  line: LineVM;
  haystack: string[];
  code: string;
}

export function buildLineIndex(lines: LineVM[]): LineIndex[] {
  return lines.map((line) => ({
    line,
    haystack: [
      normalizeText(line.name),
      normalizeText(line.short ?? ""),
      ...(line.terminals ?? []).map(normalizeText),
      ...(line.areaTags ?? []).map(normalizeText),
    ],
    code: normalizeText(line.short ?? ""),
  }));
}

export type MatchRank = "exactCode" | "namePrefix" | "terminalPrefix" | "contains";

export interface LineMatch {
  line: LineVM;
  rank: MatchRank;
}

export function searchLines(index: LineIndex[], rawQuery: string): LineMatch[] {
  const query = normalizeText(rawQuery);
  if (!query) return [];
  const hits: LineMatch[] = [];
  for (const entry of index) {
    let rank: MatchRank | null = null;
    if (entry.code === query) rank = "exactCode";
    else if (normalizeText(entry.line.name).startsWith(query)) rank = "namePrefix";
    else if (entry.haystack.some((h) => h.startsWith(query))) rank = "terminalPrefix";
    else if (entry.haystack.some((h) => h.includes(query))) rank = "contains";
    if (rank) hits.push({ line: entry.line, rank });
  }
  return hits;
}
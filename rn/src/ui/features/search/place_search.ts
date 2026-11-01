// Place search: lines passing through a searched place.
// Port of app/lib/ui/features/search/place_search.dart (simplified: matches
// area tags and terminal names instead of the learned-route index, which
// needs native geo not available here).
import type { LineVM } from "../../models/line_vm";
import { normalizeText } from "../../util/search_index";

function matchesAllTokens(fields: string[], query: string): boolean {
  const tokens = query.split(/\s+/).filter((t) => t !== "");
  if (tokens.length === 0) return false;
  return tokens.every((tok) => fields.some((f) => f.includes(tok)));
}

export interface PlaceHit {
  kind: "place";
  key: string;
  line: LineVM;
  placeName: string;
}

function placeFields(line: LineVM): string[] {
  return [...(line.areaTags ?? []), ...(line.terminals ?? [])].map(normalizeText).filter((s) => s !== "");
}

export function searchPlaces(lines: LineVM[], rawQuery: string): PlaceHit[] {
  const q = normalizeText(rawQuery);
  if (q === "") return [];
  const out: PlaceHit[] = [];
  for (const line of lines) {
    const fields = placeFields(line);
    if (fields.length === 0) continue;
    const hit = matchesAllTokens(fields, q) || fields.some((f) => f.includes(q));
    if (!hit) continue;
    const placeName = (line.areaTags ?? []).find((a) => normalizeText(a).includes(q)) ?? line.areaTags?.[0] ?? line.terminals?.[0] ?? "";
    out.push({ kind: "place", key: `place|${line.key}`, line, placeName });
  }
  return out;
}

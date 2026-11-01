// Place search: lines whose learned route passes through a searched place.
// Mirrors app/lib/ui/features/search/place_search.dart (pure part).
import { normalizeForSearch } from "../../core/text/normalize";
import { linePassesNear, minDistanceToPolylineM } from "../../core/geo/routeProximity";
import type { LatLng } from "../../core/geo/geo";
import type { Place } from "./place";
import type { LearnedRoutesIndex } from "./learnedRouteIndex";

export interface LineRef {
  key: string;
  name: string;
}

export interface PlaceHit {
  line: LineRef;
  placeName: string;
  distance: number;
}

function normalize(input: string): string {
  return normalizeForSearch(input);
}

export function searchPlaces(opts: {
  query: string;
  places: Place[];
  index: LearnedRoutesIndex;
  lines: LineRef[];
}): PlaceHit[] {
  const q = normalize(opts.query);
  if (q === "") return [];
  const matchedPlaces = opts.places.filter((p) => {
    const fields = [p.name, ...p.aliases].map(normalize);
    const tokens = q.split(" ").filter(Boolean);
    const allTokens = tokens.length > 0 && tokens.every((t) => fields.some((f) => f.includes(t)));
    const contains = fields.some((f) => f.includes(q));
    return allTokens || contains;
  });
  if (matchedPlaces.length === 0) return [];

  const lineByKey = new Map(opts.lines.map((l) => [l.key, l]));
  const best = new Map<string, PlaceHit>();
  for (const place of matchedPlaces) {
    const point: LatLng = { lat: place.lat, lng: place.lng };
    for (const entry of opts.index.entries) {
      if (!linePassesNear({ place: point, entry })) continue;
      const line = lineByKey.get(entry.code);
      if (!line) continue;
      const d = minDistanceToPolylineM(point, entry.points);
      const candidate: PlaceHit = { line, placeName: place.name, distance: d };
      const prev = best.get(line.key);
      if (!prev || d < prev.distance) best.set(line.key, candidate);
    }
  }
  return Array.from(best.values()).sort((a, b) => {
    if (a.distance !== b.distance) return a.distance - b.distance;
    return a.line.name.toLowerCase().localeCompare(b.line.name.toLowerCase());
  });
}

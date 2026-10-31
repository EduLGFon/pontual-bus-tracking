// In-memory index of published learned routes. Mirrors app/lib/domain/learning/learned_route_index.dart.
import { decodePolyline } from "../../core/geo/geo";
import type { LatLng } from "../../core/geo/geo";
import { learnedStopFromJson } from "./learnedStop";
import type { LearnedStop } from "./learnedStop";

export interface LearnedRouteEntry {
  lineId: number;
  code: string;
  direction: number;
  polyline: string;
  points: LatLng[];
  stops: LearnedStop[];
  trips: number;
}
export function learnedRouteEntryFromJson(json: Record<string, unknown>): LearnedRouteEntry {
  const polyline = typeof json["polyline"] === "string" ? (json["polyline"] as string) : "";
  const points = polyline === "" ? [] : decodePolyline(polyline);
  const rawStops = Array.isArray(json["stops"]) ? (json["stops"] as unknown[]) : [];
  return {
    lineId: Number(json["line"]),
    code: String(json["code"]),
    direction: typeof json["dir"] === "number" ? (json["dir"] as number) : 0,
    polyline,
    points,
    stops: rawStops.map((e) => learnedStopFromJson((e ?? {}) as Record<string, unknown>)),
    trips: typeof json["trips"] === "number" ? (json["trips"] as number) : 0,
  };
}

export class LearnedRoutesIndex {
  constructor(public readonly entries: LearnedRouteEntry[]) {}
  static fromJson(json: Record<string, unknown>): LearnedRoutesIndex {
    const raw = Array.isArray(json["routes"]) ? (json["routes"] as unknown[]) : [];
    return new LearnedRoutesIndex(
      raw.map((e) => learnedRouteEntryFromJson((e ?? {}) as Record<string, unknown>)),
    );
  }
  static readonly empty = new LearnedRoutesIndex([]);
}

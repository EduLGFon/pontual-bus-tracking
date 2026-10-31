// De-identified learned route polyline. Mirrors app/lib/domain/learning/learned_route.dart.
export interface LearnedRoute {
  version: number;
  direction: number;
  polyline: string | null;
  trips: number;
  computedAt: string | null;
  fallback: boolean;
}
export function learnedRouteFromJson(json: Record<string, unknown>): LearnedRoute {
  return {
    version: typeof json["v"] === "number" ? (json["v"] as number) : 0,
    direction: typeof json["dir"] === "number" ? (json["dir"] as number) : 0,
    polyline: typeof json["polyline"] === "string" ? (json["polyline"] as string) : null,
    trips: typeof json["trips"] === "number" ? (json["trips"] as number) : 0,
    computedAt: typeof json["computed_at"] === "string" ? (json["computed_at"] as string) : null,
    fallback: json["fallback"] === true,
  };
}

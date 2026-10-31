// De-identified learned stop point. Mirrors app/lib/domain/learning/learned_stop.dart.
export interface LearnedStop {
  id: string;
  ordinal: number;
  lat: number;
  lng: number;
  radiusM: number;
  passes: number;
}
export function learnedStopFromJson(json: Record<string, unknown>): LearnedStop {
  return {
    id: String(json["id"]),
    ordinal: typeof json["i"] === "number" ? (json["i"] as number) : 0,
    lat: Number(json["lat"]),
    lng: Number(json["lng"]),
    radiusM: typeof json["r"] === "number" ? (json["r"] as number) : 30,
    passes: typeof json["n"] === "number" ? (json["n"] as number) : 0,
  };
}

export interface LearnedStopsResult {
  direction: number;
  stops: LearnedStop[];
  fallback: boolean;
}
export function learnedStopsResultFromJson(json: Record<string, unknown>): LearnedStopsResult {
  const raw = Array.isArray(json["stops"]) ? (json["stops"] as unknown[]) : [];
  return {
    direction: typeof json["dir"] === "number" ? (json["dir"] as number) : 0,
    stops: raw.map((e) => learnedStopFromJson((e ?? {}) as Record<string, unknown>)),
    fallback: json["fallback"] === true,
  };
}

// De-identified public place used for place search. Mirrors app/lib/domain/learning/place.dart.
import { type LatLng } from "../../core/geo/geo";

export interface Place {
  id: string;
  name: string;
  aliases: string[];
  lat: number;
  lng: number;
}
export function placeFromJson(json: Record<string, unknown>): Place {
  const rawAliases = Array.isArray(json["aliases"]) ? (json["aliases"] as unknown[]) : [];
  return {
    id: String(json["id"]),
    name: String(json["name"]),
    aliases: rawAliases.map((e) => String(e)),
    lat: Number(json["lat"]),
    lng: Number(json["lng"]),
  };
}
export function placePoint(p: Place): LatLng {
  return { lat: p.lat, lng: p.lng };
}

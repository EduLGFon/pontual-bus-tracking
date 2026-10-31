// ETA estimate from the learning subsystem. Mirrors app/lib/domain/learning/eta_estimate.dart.
export interface EtaItem {
  vehicleId: number;
  etaS: number;
  confidence: string;
  sampleCount: number;
}
export function etaItemFromJson(json: Record<string, unknown>): EtaItem {
  return {
    vehicleId: Number(json["vehicle"]),
    etaS: typeof json["eta_s"] === "number" ? (json["eta_s"] as number) : 0,
    confidence: typeof json["conf"] === "string" ? (json["conf"] as string) : "low",
    sampleCount: typeof json["n"] === "number" ? (json["n"] as number) : 0,
  };
}

export interface EtaResult {
  stopId: string;
  nowS: number;
  items: EtaItem[];
  nextScheduledS?: number;
}
export function etaResultFromJson(json: Record<string, unknown>): EtaResult {
  const raw = Array.isArray(json["items"]) ? (json["items"] as unknown[]) : [];
  return {
    stopId: String(json["stop"]),
    nowS: typeof json["now"] === "number" ? (json["now"] as number) : 0,
    items: raw.map((e) => etaItemFromJson((e ?? {}) as Record<string, unknown>)),
    nextScheduledS:
      typeof json["next_scheduled_s"] === "number"
        ? (json["next_scheduled_s"] as number)
        : undefined,
  };
}

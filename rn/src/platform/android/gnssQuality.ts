// GNSS signal quality. Mirrors app/lib/platform/android/gnss_quality.dart.
// Signal quality only, never coordinates. Android native channel
// pontual/gnss_quality is not yet bridged in RN, so this yields an empty
// stream everywhere. Creating the stream never throws.
export interface GnssQuality {
  satsUsed: number;
  satsView: number;
  meanSnrDb: number;
}

export function gnssQualityFromMap(event: unknown): GnssQuality | null {
  if (typeof event !== "object" || event === null) return null;
  const e = event as Record<string, unknown>;
  const used = e["satsUsed"];
  const view = e["satsView"];
  const snr = e["meanSnrDb"];
  if (typeof used !== "number" || typeof view !== "number" || typeof snr !== "number") return null;
  if (used < 0 || view < 0 || used > view) return null;
  return { satsUsed: used, satsView: view, meanSnrDb: snr };
}

export type GnssQualityReader = () => AsyncIterable<GnssQuality>;

export async function* watchGnssQuality(
  reader?: GnssQualityReader,
): AsyncIterable<GnssQuality> {
  if (reader) {
    yield* reader();
    return;
  }
}

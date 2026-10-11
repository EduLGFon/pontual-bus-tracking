// Anonymous recent passages per line. In-memory only: a ring of
// vehicle-sighting epoch millis per line, no positions, no ids.
// Powers headway, history/delay and reliability cards. TTL 4 h, cap 32.
// Dropped on restart. See DECISIONS.md#D30.
import type { Store } from "../state/store.ts";

/** How long a sighting stays in the ring (4 h). */
export const PASSAGE_TTL_MS = 4 * 3600 * 1000;

/** Max sightings kept per line. */
export const PASSAGE_MAX = 32;

/** Record one vehicle sighting for [lineId] at [nowMs]. */
export function recordPassage(
  store: Store,
  lineId: number,
  nowMs: number,
): void {
  let arr = store.passages.get(lineId);
  if (!arr) {
    arr = [];
    store.passages.set(lineId, arr);
  }
  arr.push(nowMs);
  if (arr.length > PASSAGE_MAX) arr.splice(0, arr.length - PASSAGE_MAX);
  prunePassages(store, nowMs);
}

/** Drop sightings older than the TTL. Cheap: rings are tiny. */
export function prunePassages(store: Store, nowMs: number): void {
  const cutoff = nowMs - PASSAGE_TTL_MS;
  for (const [lineId, arr] of store.passages) {
    while (arr.length > 0 && arr[0] < cutoff) arr.shift();
    if (arr.length === 0) store.passages.delete(lineId);
  }
}

export interface ArrivalsPayload {
  t: number;
  line: number;
  passages: number[];
  headwayMin: number | null;
  sampleSize: number;
}

/** Public payload for one line. Passages are epoch seconds, newest last. */
export function arrivalsPayload(
  store: Store,
  lineId: number,
  nowMs: number,
): ArrivalsPayload {
  prunePassages(store, nowMs);
  const arr = store.passages.get(lineId) ?? [];
  const passages = arr.map((ms) => Math.floor(ms / 1000));
  return {
    t: Math.floor(nowMs / 1000),
    line: lineId,
    passages,
    headwayMin: medianHeadwayMin(arr),
    sampleSize: arr.length,
  };
}

function medianHeadwayMin(sortedMs: number[]): number | null {
  if (sortedMs.length < 2) return null;
  const gaps: number[] = [];
  for (let i = 1; i < sortedMs.length; i++) {
    gaps.push((sortedMs[i] - sortedMs[i - 1]) / 60000);
  }
  gaps.sort((a, b) => a - b);
  const mid = Math.floor(gaps.length / 2);
  const median = gaps.length % 2 === 1
    ? gaps[mid]
    : (gaps[mid - 1] + gaps[mid]) / 2;
  return Math.round(median * 10) / 10;
}

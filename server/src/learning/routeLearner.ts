// Route geometry helpers for the learning subsystem.
// Ports the Douglas-Peucker simplification from tools/route/main.ts and
// adds the smoothing + size-budget steps from docs/data-learning.md 5.1.
// Pure functions only; no I/O, no clock.

export interface Pt {
  lat: number;
  lng: number;
}

function perpDistM(p: Pt, a: Pt, b: Pt): number {
  const kx = 111320 * Math.cos(((a.lat + b.lat) / 2 * Math.PI) / 180);
  const px = (p.lng - a.lng) * kx;
  const py = (p.lat - a.lat) * 111320;
  const bx = (b.lng - a.lng) * kx;
  const by = (b.lat - a.lat) * 111320;
  const len2 = bx * bx + by * by;
  let t = len2 === 0 ? 0 : (px * bx + py * by) / len2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - t * bx, py - t * by);
}

/** Douglas-Peucker simplification, keeps endpoints. */
export function simplify(points: Pt[], tolM: number): Pt[] {
  if (points.length <= 2) return [...points];
  const keep = new Array<boolean>(points.length).fill(false);
  keep[0] = keep[points.length - 1] = true;
  const stack: [number, number][] = [[0, points.length - 1]];
  while (stack.length > 0) {
    const [first, last] = stack.pop()!;
    let best = -1;
    let bestD = 0;
    for (let i = first + 1; i < last; i++) {
      const d = perpDistM(points[i], points[first], points[last]);
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > tolM && best >= 0) {
      keep[best] = true;
      stack.push([first, best], [best, last]);
    }
  }
  return points.filter((_, i) => keep[i]);
}

/** 3-point moving average along the sequence. */
export function smooth(points: Pt[]): Pt[] {
  if (points.length < 3) return [...points];
  const out: Pt[] = [points[0]];
  for (let i = 1; i < points.length - 1; i++) {
    out.push({
      lat: (points[i - 1].lat + points[i].lat + points[i + 1].lat) / 3,
      lng: (points[i - 1].lng + points[i].lng + points[i + 1].lng) / 3,
    });
  }
  out.push(points[points.length - 1]);
  return out;
}

/**
 * Build a polyline from progress-binned centroids per docs/data-learning.md 5.1.
 * Returns null when the input is too sparse (>20% bins missing) or too short.
 * Applies smoothing, Douglas-Peucker (5 m, then 10 m on size overflow) and an
 * 8 KB size cap. Caller encodes the returned points.
 */
export function buildRoutePoints(
  binned: Array<{ lat: number; lng: number } | null>,
  minBinsFraction = 0.8,
): Pt[] | null {
  const present = binned.filter((p) => p !== null) as Pt[];
  if (present.length < 2) return null;
  if (present.length / binned.length < minBinsFraction) return null;
  // linearly interpolate missing bins so the polyline stays continuous
  const filled: Pt[] = [];
  let lastIdx = -1;
  for (let i = 0; i < binned.length; i++) {
    if (binned[i]) {
      filled.push(binned[i] as Pt);
      lastIdx = i;
      continue;
    }
    // find next present
    let nextIdx = -1;
    for (let j = i + 1; j < binned.length; j++) {
      if (binned[j]) {
        nextIdx = j;
        break;
      }
    }
    if (lastIdx < 0 || nextIdx < 0) {
      // edge gap: skip (trim handled by caller's bin range)
      continue;
    }
    const a = binned[lastIdx] as Pt;
    const bpt = binned[nextIdx] as Pt;
    const span = nextIdx - lastIdx;
    const frac = (i - lastIdx) / span;
    filled.push({
      lat: a.lat + (bpt.lat - a.lat) * frac,
      lng: a.lng + (bpt.lng - a.lng) * frac,
    });
  }
  if (filled.length < 2) return null;
  const smoothed = smooth(filled);
  let simplified = simplify(smoothed, 5);
  // size cap: 8 KB. Approximate encoded length via JSON-ish byte count of
  // the polyline string is checked by caller; here we just retry at 10 m
  // if the point count is large. Caller enforces the byte cap.
  if (simplified.length > 400) {
    simplified = simplify(smoothed, 10);
  }
  return simplified;
}

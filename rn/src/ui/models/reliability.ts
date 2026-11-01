// Reliability view model. Port of app/lib/ui/models/reliability.dart.
export interface ReliabilityVM {
  typicalDelayMin: number;
  sampleSize: number;
  bars: number[];
}

export function reliabilityFromJson(json: any): ReliabilityVM {
  return {
    typicalDelayMin: typeof json?.typical_delay_min === "number" ? json.typical_delay_min : 0,
    sampleSize: typeof json?.sample_size === "number" ? json.sample_size : 0,
    bars: Array.isArray(json?.bars)
      ? json.bars.filter((v: any) => typeof v === "number").map((v: number) => Math.min(1, Math.max(0, v)))
      : [],
  };
}

export function reliabilityToJson(r: ReliabilityVM): Record<string, unknown> {
  return { typical_delay_min: r.typicalDelayMin, sample_size: r.sampleSize, bars: r.bars };
}

export function reliabilityOf(params: {
  passages: number[];
  headwayMin: number | null;
  scheduledHeadwayMin: number | null;
}): ReliabilityVM | null {
  const { passages, headwayMin, scheduledHeadwayMin } = params;
  if (passages.length < 2 || headwayMin == null || scheduledHeadwayMin == null || scheduledHeadwayMin <= 0) return null;
  const delay = Math.max(0, Math.round(headwayMin - scheduledHeadwayMin));
  const gaps: number[] = [];
  for (let i = 1; i < passages.length; i++) gaps.push((passages[i] - passages[i - 1]) / 60);
  const recent = gaps.length <= 8 ? gaps : gaps.slice(gaps.length - 8);
  let peak = 1;
  for (const g of recent) if (g > peak) peak = g;
  return {
    typicalDelayMin: delay,
    sampleSize: passages.length,
    bars: recent.map((g) => Math.min(1, Math.max(0, g / peak))),
  };
}

export function scheduledHeadwayOf(times: string[]): number | null {
  if (times.length < 2) return null;
  const minutes = times.map((t) => {
    const parts = t.split(":");
    return parseInt(parts[0] ?? "0", 10) * 60 + parseInt(parts[1] ?? "0", 10);
  }).sort((a, b) => a - b);
  const gaps: number[] = [];
  for (let i = 1; i < minutes.length; i++) gaps.push(minutes[i] - minutes[i - 1]);
  gaps.sort((a, b) => a - b);
  const mid = Math.floor(gaps.length / 2);
  const median = gaps.length % 2 === 1 ? gaps[mid] : (gaps[mid - 1] + gaps[mid]) / 2;
  return median;
}
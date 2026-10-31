// Frame timing. Port of app/lib/ui/util/frame_timing.dart.
export interface FrameTimingStats {
  frames: number;
  p50BuildMs: number;
  p95BuildMs: number;
  p50RasterMs: number;
  p95RasterMs: number;
}

function percentile(values: number[], percent: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  let rank = Math.ceil((percent / 100) * sorted.length) - 1;
  rank = Math.max(0, Math.min(sorted.length - 1, rank));
  return sorted[rank];
}

export function summarizeBuildRaster(buildMs: number[], rasterMs: number[]): FrameTimingStats {
  if (buildMs.length === 0 && rasterMs.length === 0) {
    return { frames: 0, p50BuildMs: 0, p95BuildMs: 0, p50RasterMs: 0, p95RasterMs: 0 };
  }
  const build = [...buildMs].sort((a, b) => a - b);
  const raster = [...rasterMs].sort((a, b) => a - b);
  return {
    frames: Math.max(buildMs.length, rasterMs.length),
    p50BuildMs: percentile(build, 50),
    p95BuildMs: percentile(build, 95),
    p50RasterMs: percentile(raster, 50),
    p95RasterMs: percentile(raster, 95),
  };
}
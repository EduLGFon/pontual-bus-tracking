// Debug-only frame-timing logger. Prints p50/p95 build and raster times
// for each screen during manual QA. Never shipped: every entry point is
// guarded by kDebugMode, and release builds tree-shake the callback.
// See docs/ui/UI_SPEC.md 11.4.
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Summary of one window of frame timings.
class FrameTimingStats {
  /// Creates the summary, all in milliseconds.
  const FrameTimingStats({
    required this.frames,
    required this.p50BuildMs,
    required this.p95BuildMs,
    required this.p50RasterMs,
    required this.p95RasterMs,
  });

  /// Frames in the window.
  final int frames;

  /// Median build time in ms.
  final double p50BuildMs;

  /// p95 build time in ms.
  final double p95BuildMs;

  /// Median raster time in ms.
  final double p50RasterMs;

  /// p95 raster time in ms.
  final double p95RasterMs;

  @override
  String toString() {
    return 'frames=$frames build p50=${p50BuildMs.toStringAsFixed(1)}ms '
        'p95=${p95BuildMs.toStringAsFixed(1)}ms raster '
        'p50=${p50RasterMs.toStringAsFixed(1)}ms '
        'p95=${p95RasterMs.toStringAsFixed(1)}ms';
  }
}

/// Summarises [timings]. Pure, so unit tests cover the maths.
FrameTimingStats summarizeTimings(List<FrameTiming> timings) {
  return summarizeBuildRaster(
    timings
        .map((FrameTiming t) => t.buildDuration.inMicroseconds / 1000)
        .toList(),
    timings
        .map((FrameTiming t) => t.rasterDuration.inMicroseconds / 1000)
        .toList(),
  );
}

/// Summarises parallel build and raster durations in ms. Pure.
FrameTimingStats summarizeBuildRaster(
  List<double> buildMs,
  List<double> rasterMs,
) {
  if (buildMs.isEmpty && rasterMs.isEmpty) {
    return const FrameTimingStats(
      frames: 0,
      p50BuildMs: 0,
      p50RasterMs: 0,
      p95BuildMs: 0,
      p95RasterMs: 0,
    );
  }
  final List<double> build = List<double>.from(buildMs)..sort();
  final List<double> raster = List<double>.from(rasterMs)..sort();
  return FrameTimingStats(
    frames: buildMs.length > rasterMs.length ? buildMs.length : rasterMs.length,
    p50BuildMs: _percentile(build, 50),
    p95BuildMs: _percentile(build, 95),
    p50RasterMs: _percentile(raster, 50),
    p95RasterMs: _percentile(raster, 95),
  );
}

/// Nearest-rank percentile of sorted [values].
double _percentile(List<double> values, int percent) {
  if (values.isEmpty) {
    return 0;
  }
  int rank = ((percent / 100) * values.length).ceil() - 1;
  rank = rank.clamp(0, values.length - 1);
  return values[rank];
}

/// Installs the debug frame-timing callback labelled [screen]. No-op in
/// release builds. Call once per screen under test during manual QA.
void installFrameTimingLogger(String screen) {
  if (!kDebugMode) {
    return;
  }
  final List<FrameTiming> window = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    window.addAll(timings);
    if (window.length < 120) {
      return;
    }
    final FrameTimingStats stats = summarizeTimings(
      window.toList(growable: false),
    );
    window.clear();
    debugPrint('frame[$screen] $stats');
  });
}

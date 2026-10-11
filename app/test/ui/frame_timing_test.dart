// Unit tests for the frame-timing maths. The logger itself is debug-only
// and prints during manual QA, so only the pure summary is asserted here.
// See docs/ui/UI_SPEC.md 11.4.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/util/frame_timing.dart';

void main() {
  test('empty window summarises to zeros', () {
    final FrameTimingStats stats = summarizeBuildRaster(
      const <double>[],
      const <double>[],
    );
    expect(stats.frames, 0);
    expect(stats.p50BuildMs, 0);
    expect(stats.p95BuildMs, 0);
  });

  test('percentiles follow nearest rank', () {
    final List<double> build = List<double>.generate(100, (int i) => i + 1);
    final List<double> raster = List<double>.generate(
      100,
      (int i) => 2 * (i + 1),
    );
    final FrameTimingStats stats = summarizeBuildRaster(build, raster);
    expect(stats.frames, 100);
    expect(stats.p50BuildMs, 50);
    expect(stats.p95BuildMs, 95);
    expect(stats.p50RasterMs, 100);
    expect(stats.p95RasterMs, 190);
  });
}

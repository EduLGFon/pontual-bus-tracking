// On-device performance run: drives Home -> Lines -> Line on a real
// Android build in profile mode, collects frame timings per phase, and
// prints markers the host driver (tools/perf/device_run.py) watches in
// logcat to capture PSS and screenshots at the right moment. Fixed sleeps
// keep host and device in sync without any protocol.
// See docs/ui/PERF.md and docs/ui/UI_SPEC.md 17.4.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pontual/main.dart' as app;
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/frame_timing.dart';

/// Prints a marker line the host watches for in logcat.
void mark(String name) {
  debugPrint('PERF_MARK $name');
}

/// Waits up to [timeout] for [finder], pumping one frame per second.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder,
  Duration timeout,
) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(seconds: 1));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw StateError('timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device perf: home, lines, line soak', (
    WidgetTester tester,
  ) async {
    final List<FrameTiming> window = <FrameTiming>[];
    SchedulerBinding.instance.addTimingsCallback(window.addAll);

    app.main();
    await waitFor(
      tester,
      find.text(UiStrings.homeSubtitle),
      const Duration(seconds: 90),
    );
    // Settle past tile and live refreshes, then measure Home idle.
    await tester.pump(const Duration(seconds: 20));
    debugPrint('PERF_TIMINGS home ${summarizeTimings(window.toList())}');
    window.clear();
    mark('HOME_MEM');

    await tester.tap(find.text(UiStrings.homeAllLines));
    await tester.pump(const Duration(seconds: 2));
    await waitFor(tester, find.byType(LineRow), const Duration(seconds: 30));
    await tester.tap(find.byType(LineRow).first);
    await tester.pump(const Duration(seconds: 2));
    await waitFor(tester, find.byType(FlutterMap), const Duration(seconds: 60));
    // Let tiles and the first snapshot land.
    await tester.pump(const Duration(seconds: 30));
    debugPrint('PERF_TIMINGS line_settle ${summarizeTimings(window.toList())}');
    window.clear();

    // Soak with a pan every 30 s to keep exercising the marker layer.
    for (int i = 0; i < 4; i++) {
      await tester.fling(find.byType(FlutterMap), const Offset(-200, 0), 800);
      await tester.pump(const Duration(seconds: 30));
      if (i == 2) {
        mark('LINE_MEM');
      }
    }
    debugPrint('PERF_TIMINGS line_soak ${summarizeTimings(window.toList())}');
    window.clear();
    mark('DONE');
  });
}

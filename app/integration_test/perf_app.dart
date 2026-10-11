// Measurement-only entrypoint for profile runs. Boots the real app and
// drives Home -> Lines -> Line on a fixed script while collecting frame
// timings; the host driver (tools/perf/device_run.py) watches logcat for
// the markers to capture PSS, screenshots and swipes. Never referenced by
// release builds, which boot from lib/main.dart.
// Run: flutter run --profile -t integration_test/perf_app.dart
// See docs/ui/PERF.md and docs/ui/UI_SPEC.md 17.4.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/router/app_router.dart';
import 'package:pontual/ui/util/frame_timing.dart';

/// Line driven to, a pilot line with timetables in the bundle.
const String perfLineKey = '60-litoraneo-aviacao';

void main() {
  final GoRouter router = buildUiRouter();
  runApp(ProviderScope(child: _PerfApp(router: router)));
  unawaited(_script(router));
}

/// Root widget. Mirrors the release bootstrap without the prefs read.
class _PerfApp extends StatelessWidget {
  /// Creates the root.
  const _PerfApp({required this.router});

  /// Router driven by the script.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return pontualApp(mode: ThemeMode.system, router: router);
  }
}

/// Prints a marker line the host watches for in logcat.
void mark(String name) {
  debugPrint('PERF_MARK $name');
}

/// Scripted run with fixed phases so the host stays in sync.
Future<void> _script(GoRouter router) async {
  final List<FrameTiming> window = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback(window.addAll);

  // Home idle, past first paint and live refreshes.
  await Future<void>.delayed(const Duration(seconds: 25));
  debugPrint('PERF_TIMINGS home ${summarizeTimings(window.toList())}');
  window.clear();
  mark('HOME_MEM');

  unawaited(router.push('/lines'));
  await Future<void>.delayed(const Duration(seconds: 10));
  unawaited(router.push('/line/$perfLineKey'));
  // Tiles plus the first snapshot.
  await Future<void>.delayed(const Duration(seconds: 40));
  debugPrint('PERF_TIMINGS line_settle ${summarizeTimings(window.toList())}');
  window.clear();
  mark('LINE_SOAK');

  // The host swipes the map during this soak.
  await Future<void>.delayed(const Duration(minutes: 2));
  mark('LINE_MEM');
  await Future<void>.delayed(const Duration(seconds: 10));
  debugPrint('PERF_TIMINGS line_soak ${summarizeTimings(window.toList())}');
  window.clear();
  mark('DONE');
}

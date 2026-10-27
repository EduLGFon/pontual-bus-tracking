// Lifecycle-aware periodic ticks. Timers stop while the app is not
// resumed, so screens do not wake the isolate to rebuild invisible
// content, and resume without a burst of catch-up ticks. Consumers own
// cancellation by cancelling the subscription.
// See PLAN.md 10.2.5 and 10.3.3.
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Observes lifecycle changes without AppLifecycleListener's strict
/// transition assertions, so the helper is safe with any platform state
/// sequence and in tests.
class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);

  final void Function(AppLifecycleState) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}

/// Emits an increasing counter every [period] while the app is resumed.
/// The timer is created on listen and cancelled on cancel.
Stream<int> lifecycleTicks(Duration period) {
  // ignore: close_sinks - infinite stream; closing on cancel deadlocks.
  late final StreamController<int> controller;
  Timer? timer;
  _LifecycleObserver? observer;
  int count = 0;

  void stop() {
    timer?.cancel();
    timer = null;
  }

  void start() {
    timer ??= Timer.periodic(period, (_) => controller.add(++count));
  }

  void sync(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else {
      stop();
    }
  }

  controller = StreamController<int>(
    onListen: () {
      final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
      // A null state is the test binding's initial state: treat it as
      // resumed so unit and widget tests keep their deterministic ticks.
      sync(state ?? AppLifecycleState.resumed);
      observer = _LifecycleObserver(sync);
      WidgetsBinding.instance.addObserver(observer!);
    },
    onCancel: () {
      stop();
      final _LifecycleObserver? current = observer;
      if (current != null) {
        WidgetsBinding.instance.removeObserver(current);
        observer = null;
      }
    },
  );
  return controller.stream;
}

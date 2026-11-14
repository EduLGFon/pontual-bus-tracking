// Clock abstraction. Production code never calls DateTime.now directly in
// logic; tests inject FakeClock. See ARCHITECTURE.md 14.2.

/// Abstraction over wall-clock and monotonic time.
abstract class Clock {
  /// Wall-clock time in milliseconds since epoch.
  int nowMs();

  /// Monotonic time in milliseconds for ages and durations.
  int monotonicMs();
}

/// System implementation backed by DateTime and Stopwatch.
class SystemClock implements Clock {
  /// Creates a system clock.
  SystemClock() : _sw = Stopwatch()..start();

  final Stopwatch _sw;

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  int monotonicMs() => _sw.elapsedMilliseconds;
}

/// Fake clock for deterministic tests.
class FakeClock implements Clock {
  /// Creates a fake clock starting at [startMs].
  FakeClock([int startMs = 0]) : _wall = startMs, _mono = startMs;

  int _wall;
  int _mono;

  /// Advances both clocks by [ms].
  void advance(int ms) {
    _wall += ms;
    _mono += ms;
  }

  @override
  int nowMs() => _wall;

  @override
  int monotonicMs() => _mono;
}

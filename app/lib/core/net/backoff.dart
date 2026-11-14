// Retry backoff with jitter. Steps 5/10/20/40/60 seconds with bounded
// jitter; randomness is injectable so tests are deterministic.
// See ARCHITECTURE.md 15.3 PingClient expectations.
import 'dart:math';

/// Backoff ladder in seconds.
const List<int> backoffStepsS = <int>[5, 10, 20, 40, 60];

/// Maximum jitter applied symmetrically around a step, in seconds.
const int backoffJitterS = 2;

/// Computes capped backoff delays with jitter.
class Backoff {
  /// Creates a backoff with an optional [random] source.
  Backoff({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Delay for [attempt] (0-based), clamped to the last step, plus jitter
  /// in [-jitterS, +jitterS]. Never negative.
  Duration delayFor(int attempt, [int jitterS = backoffJitterS]) {
    final int step = backoffStepsS[attempt.clamp(0, backoffStepsS.length - 1)];
    final double span = jitterS * 2 + 1;
    final int jitter = (_random.nextDouble() * span).floor() - jitterS;
    final int total = step + jitter;
    return Duration(seconds: total < 0 ? 0 : total);
  }

  /// Resets any state. Stateless implementation kept for API symmetry.
  void reset() {}
}

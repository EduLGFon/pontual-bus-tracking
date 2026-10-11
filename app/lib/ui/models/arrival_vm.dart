// The one shape for "a bus arrives at X at Y". Timetable arrivals, live
// arrivals and (later) predictions all become an ArrivalVM, so a screen
// never learns where the value came from. See docs/ui/UI_SPEC.md 6.2.
import 'package:flutter/foundation.dart';
import 'package:pontual/ui/models/certainty.dart';

/// One arrival, from any source.
@immutable
class ArrivalVM {
  /// Creates an arrival.
  const ArrivalVM({
    required this.lineKey,
    required this.at,
    required this.certainty,
    required this.asOf,
    this.stopKey,
    this.headsign,
    this.originLabel,
    this.confidence,
    this.delaySeconds,
  });

  /// Line the arrival belongs to.
  final String lineKey;

  /// When the bus is expected.
  final DateTime at;

  /// How much the UI trusts the value.
  final Certainty certainty;

  /// When the value was produced, for age display.
  final DateTime asOf;

  /// Stop or terminal the arrival refers to, when known.
  final String? stopKey;

  /// Direction or destination label, when known.
  final String? headsign;

  /// Origin terminal of the departure.
  final String? originLabel;

  /// Prediction confidence, 0 low to 2 high. Predicted only.
  final int? confidence;

  /// Signed delay in seconds against the timetable. Later features.
  final int? delaySeconds;

  /// True when the arrival already happened by [now].
  bool isPast(DateTime now) => at.isBefore(now);

  /// Seconds from [now] to [at], never negative.
  int secondsUntil(DateTime now) {
    final int delta = at.difference(now).inSeconds;
    return delta < 0 ? 0 : delta;
  }
}

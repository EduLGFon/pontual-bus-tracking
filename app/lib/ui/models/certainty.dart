// The Certainty enum: the single vocabulary for every time, position or
// estimate the UI shows. Live, predicted, scheduled and stale are all
// different promises and never get mixed in one number.
// See docs/ui/UI_SPEC.md 3.

/// How much the UI trusts a value it shows.
enum Certainty {
  /// Measured by a rider phone in the last 45 s.
  live,

  /// Estimated from recent data and line pace (future feature).
  predicted,

  /// From the static timetable only.
  scheduled,

  /// Was live, no update for more than 45 s.
  stale,
}

/// Seconds after which a live value becomes stale. Mirrors the data layer.
const int liveFreshS = 45;

/// Certainty implied by the age of a live value.
Certainty certaintyForAge(int ageS) {
  return ageS > liveFreshS ? Certainty.stale : Certainty.live;
}

/// Label of a certainty in pt-BR, taken from the strings file by callers.
/// Kept here so tests can switch over the whole vocabulary.
const Map<Certainty, String> certaintyLabelKeys = <Certainty, String>{
  Certainty.live: 'live',
  Certainty.predicted: 'predicted',
  Certainty.scheduled: 'scheduled',
  Certainty.stale: 'stale',
};

/// True when [value] is a measurement rather than an estimate.
bool isMeasured(Certainty value) => value == Certainty.live;

/// Ordering used when merging sources: live wins over predicted, which
/// wins over scheduled. Stale never wins anything.
int certaintyRank(Certainty value) {
  return switch (value) {
    Certainty.live => 0,
    Certainty.predicted => 1,
    Certainty.scheduled => 2,
    Certainty.stale => 3,
  };
}

/// Debug label, used in tests and diagnostics only.
extension CertaintyDebug on Certainty {
  /// Lowercase name of the certainty.
  String get debugName => certaintyLabelKeys[this] ?? 'unknown';
}

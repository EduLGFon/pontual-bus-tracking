// Sampling policy. Pure decision of location-request mode from role,
// motion, and connectivity, with hysteresis: downgrades wait 30 s so the
// stream is never recreated more than once per 30 s, but upgrades to a
// faster cadence apply immediately so a new leader reaches its 5 s rate
// on the next fix instead of stalling a full hysteresis window.
// See PLAN.md 8.6.

/// Location request modes.
enum SamplingMode {
  /// Role W: balanced accuracy about every 5 s.
  waiting,

  /// Role L moving: high accuracy about every 5 s.
  leaderMoving,

  /// Role L still: balanced about every 15 s.
  leaderStill,

  /// Role F: low power about every 45 s with jitter.
  follower,

  /// Offline: follower-like sampling, probes only.
  offlineSaver,

  /// Stream stopped with a banner.
  paused,
}

/// Minimum interval between stream recreations in milliseconds.
/// Applies to downgrades only; upgrades to a faster cadence or to high
/// accuracy bypass it.
const int streamHysteresisMs = 30000;

/// Nominal stream interval per mode in seconds. Mirrors
/// `settingsFor` in the location service: faster means smaller.
/// Waiting and leaderMoving share the 5 s rate so the first vehicle
/// publishes one interval after motion starts; the W to L switch is
/// still an accuracy upgrade (medium to high) and bypasses hysteresis.
int intervalSForMode(SamplingMode mode) {
  switch (mode) {
    case SamplingMode.leaderMoving:
    case SamplingMode.waiting:
      return 5;
    case SamplingMode.leaderStill:
      return 15;
    case SamplingMode.follower:
    case SamplingMode.offlineSaver:
    case SamplingMode.paused:
      return 45;
  }
}

/// Decides the sampling mode. Returns [current] unchanged when only the
/// hysteresis window blocks a downgrade. Upgrades to a faster cadence
/// (shorter interval) or to high accuracy apply immediately: holding a
/// fresh leader at the old waiting rate for 30 s was the dominant
/// steady-state latency behind the 15-25 s map delays. Waiting and
/// leaderMoving share the 5 s rate, so the W to L switch bypasses on
/// accuracy (medium to high).
SamplingMode decideMode({
  required SamplingMode current,
  required TripModeInput input,
  required int nowMs,
  required int lastChangeMs,
}) {
  final SamplingMode wanted = _wanted(input);
  if (wanted == current) {
    return current;
  }
  if (intervalSForMode(wanted) < intervalSForMode(current)) {
    return wanted;
  }
  if (wanted == SamplingMode.leaderMoving &&
      current != SamplingMode.leaderMoving) {
    return wanted;
  }
  if (nowMs - lastChangeMs < streamHysteresisMs) {
    return current;
  }
  return wanted;
}

/// Inputs to the sampling decision.
class TripModeInput {
  /// Creates sampling inputs.
  const TripModeInput({
    required this.role,
    required this.speedMps,
    required this.offline,
    required this.stillS,
    required this.paused,
  });

  /// Server role L, F, or W.
  final String role;

  /// Current speed in meters per second.
  final double speedMps;

  /// True after 3 failed sends or 120 s without success.
  final bool offline;

  /// Seconds without motion.
  final int stillS;

  /// True when permission revoked, location off, or mock detected.
  final bool paused;
}

SamplingMode _wanted(TripModeInput input) {
  if (input.paused) {
    return SamplingMode.paused;
  }
  if (input.offline) {
    return SamplingMode.offlineSaver;
  }
  switch (input.role) {
    case 'L':
      if (input.stillS >= 60) {
        return SamplingMode.leaderStill;
      }
      return SamplingMode.leaderMoving;
    case 'F':
      return SamplingMode.follower;
    default:
      return SamplingMode.waiting;
  }
}

/// Wanted sampling mode without hysteresis. The caller (LocationService
/// or TripController) applies the 30 s stream-recreation guard.
SamplingMode wantedMode(TripModeInput input) => _wanted(input);

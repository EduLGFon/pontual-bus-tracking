// Auto-end policy. Pure evaluation of end conditions: GPS off, permission
// revoked, walking-prompt timeout, and maximum duration. Time is a
// parameter; the controller owns timers and dialogs. See ARCHITECTURE.md RF04.

/// Reasons the client ends a trip by itself.
enum AutoEndReason {
  /// Location services off for too long.
  gpsOff,

  /// Location permission revoked mid-trip.
  permissionRevoked,

  /// Walking prompt unanswered for 5 minutes.
  walkingTimeout,

  /// Hard 4-hour cap reached client-side.
  maxDuration,
}

/// Thresholds in milliseconds.
const int gpsOffAfterMs = 5 * 60 * 1000;

/// Walking prompt timeout in milliseconds.
const int walkingTimeoutMs = 5 * 60 * 1000;

/// Slow-speed duration before the RF16 prompt appears in milliseconds.
/// Long enough to survive traffic jams and construction stops without
/// nagging; forgotten stationary trips still end 5 min after the prompt.
const int walkingPromptAfterMs = 15 * 60 * 1000;

/// Speed below which a fix counts as slow (walking or stopped bus).
const double walkingSlowMaxMps = 0.5;

/// Hard trip cap in milliseconds.
const int tripMaxMs = 4 * 3600 * 1000;

/// Inputs to the auto-end decision. Null times mean the condition never
/// started.
class AutoEndInput {
  /// Creates auto-end inputs.
  const AutoEndInput({
    required this.startedAtMs,
    required this.gpsOffSinceMs,
    required this.permissionRevoked,
    required this.walkingPromptAtMs,
  });

  /// Trip start time.
  final int startedAtMs;

  /// When location services went off, if off.
  final int? gpsOffSinceMs;

  /// True when the permission was revoked mid-trip.
  final bool permissionRevoked;

  /// When the walking prompt was shown, if shown.
  final int? walkingPromptAtMs;
}

/// First firing auto-end reason, or null when the trip continues.
AutoEndReason? autoEndReason(AutoEndInput input, int nowMs) {
  if (input.permissionRevoked) {
    return AutoEndReason.permissionRevoked;
  }
  final int? gpsOff = input.gpsOffSinceMs;
  if (gpsOff != null && nowMs - gpsOff > gpsOffAfterMs) {
    return AutoEndReason.gpsOff;
  }
  final int? prompt = input.walkingPromptAtMs;
  if (prompt != null && nowMs - prompt > walkingTimeoutMs) {
    return AutoEndReason.walkingTimeout;
  }
  if (nowMs - input.startedAtMs > tripMaxMs) {
    return AutoEndReason.maxDuration;
  }
  return null;
}

/// True when the RF16 walking prompt should appear: the device has been
/// slow for at least [walkingPromptAfterMs] and no prompt is showing.
/// Pure; the controller owns the slow-speed clock and the dialog.
bool walkingPromptDue({
  required int? slowSinceMs,
  required int? promptAtMs,
  required int nowMs,
}) {
  if (promptAtMs != null) {
    return false;
  }
  if (slowSinceMs == null) {
    return false;
  }
  return nowMs - slowSinceMs >= walkingPromptAfterMs;
}

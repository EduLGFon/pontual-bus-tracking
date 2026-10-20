// Web visibility policy. Sharing works only in the foreground: when the
// page is hidden for more than 60 s the controller pauses sends until
// the page is visible again. Pure Dart so it is unit testable; the
// widget layer feeds lifecycle events. See PLAN.md 8.12.

/// Milliseconds of hidden time before a web trip pauses.
const int webHiddenPauseMs = 60 * 1000;

/// Returns true when [hiddenForMs] reaches the pause threshold.
bool webShouldPause(int hiddenForMs) => hiddenForMs >= webHiddenPauseMs;

/// Tracks hidden time for a web trip. Feed show/hide events with the
/// clock time in milliseconds; [paused] turns true once the page has
/// been hidden for at least [webHiddenPauseMs].
class WebVisibilityTracker {
  /// Creates a tracker.
  WebVisibilityTracker();

  int? _hiddenSinceMs;

  /// True while the trip is paused for a long-hidden page.
  bool paused = false;

  /// Call when the page becomes hidden at [nowMs].
  void onHidden(int nowMs) {
    _hiddenSinceMs ??= nowMs;
  }

  /// Call when the page becomes visible again. Clears the pause.
  void onVisible() {
    _hiddenSinceMs = null;
    paused = false;
  }

  /// Call with the current time to re-evaluate the pause. Used by a
  /// periodic check while hidden.
  void check(int nowMs) {
    final int? since = _hiddenSinceMs;
    if (since == null) {
      return;
    }
    if (nowMs - since >= webHiddenPauseMs) {
      paused = true;
    }
  }

  /// Hidden duration in ms, or 0 while visible. Read on resume to pass
  /// the real gap to the controller even when the pause timer was frozen.
  int hiddenFor(int nowMs) {
    final int? since = _hiddenSinceMs;
    if (since == null) {
      return 0;
    }
    return nowMs - since;
  }
}

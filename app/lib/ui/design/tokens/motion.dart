// Motion tokens. Everything animateable has a duration from this table and
// a curve; nothing else may invent a value. Reduced motion collapses every
// duration to instant and removes pulses. See docs/ui/UI_SPEC.md 4.4.
import 'package:flutter/widgets.dart';

/// Durations used by the new UI.
class Motion {
  /// Private constructor: this class only holds duration constants.
  const Motion._();

  /// Pressed states and reduced-motion fades.
  static const Duration instant = Duration(milliseconds: 80);

  /// Chip and segment changes, ETA digit change.
  static const Duration fast = Duration(milliseconds: 140);

  /// Page transitions, snap to certainty change.
  static const Duration base = Duration(milliseconds: 200);

  /// Sheet settle and first-load reveals.
  static const Duration slow = Duration(milliseconds: 320);

  /// Live pulse cycle for the shared controller.
  static const Duration pulse = Duration(milliseconds: 1600);

  /// Marker position interpolation.
  static const Duration markerMove = Duration(milliseconds: 800);
}

/// Curves used by the new UI.
class MotionCurves {
  /// Private constructor: this class only holds curve constants.
  const MotionCurves._();

  /// Enter.
  static const Curve enter = Curves.easeOutCubic;

  /// Exit.
  static const Curve exit = Curves.easeInCubic;

  /// Move.
  static const Curve move = Curves.easeInOutCubic;
}

/// Duration for [enabled]. When false every animation runs at [Motion.instant].
Duration motionDuration(Duration value, {required bool enabled}) {
  return enabled ? value : Motion.instant;
}

/// Stored reduce-motion preference: follow the system accessibility setting
/// until the user explicitly changes the switch; after that the explicit
/// choice wins. Shown in the UI as a plain switch on the effective value.
enum ReduceMotionMode {
  /// Follow `MediaQuery.disableAnimations`.
  system,

  /// Always reduce motion.
  on,

  /// Never reduce motion from the app setting (the system flag still
  /// applies where widgets check it directly).
  off,
}

/// One helper for the effective motion. Callers pass the stored mode they
/// already read from `settingsProvider`; the system flag is OR-ed in, so
/// existing `MediaQuery` checks keep working unchanged.
abstract final class AppMotion {
  /// Private constructor: only the static helpers below exist.
  const AppMotion._();

  /// True when motion should be reduced for [mode] in [context].
  static bool reduced(BuildContext context, ReduceMotionMode mode) {
    switch (mode) {
      case ReduceMotionMode.on:
        return true;
      case ReduceMotionMode.off:
        return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      case ReduceMotionMode.system:
        return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    }
  }

  /// [normal] when motion is allowed, zero-length when reduced.
  static Duration duration(
    BuildContext context,
    ReduceMotionMode mode,
    Duration normal,
  ) {
    return reduced(context, mode) ? Duration.zero : normal;
  }
}

// Motion tokens. Everything animateable has a duration from this table and
// a curve; nothing else may invent a value. Reduced motion collapses every
// duration to instant and removes pulses. See docs/ui/UI_SPEC.md 4.4.
import 'package:flutter/animation.dart';

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

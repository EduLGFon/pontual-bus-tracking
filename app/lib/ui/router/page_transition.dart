// Page transition: fade-through 200 ms with an 8 dp upward slide. Reduced
// motion shortens the duration to instant. Never used with a Hero on a map.
// See docs/ui/UI_SPEC.md 6.6 and 9.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/motion.dart';

/// Transition duration for the current reduced-motion setting.
Duration transitionDurationOf(BuildContext context) {
  final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return reduce ? Motion.instant : Motion.base;
}

/// Builds the page transition for a route.
Widget fadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: reduce ? Curves.linear : MotionCurves.enter,
  );
  return SlideTransition(
    position: reduce
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(
            begin: const Offset(0, 0.0125),
            end: Offset.zero,
          ).animate(curved),
    child: FadeTransition(opacity: curved, child: child),
  );
}

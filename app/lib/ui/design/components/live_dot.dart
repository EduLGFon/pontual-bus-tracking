// LiveDot: 8 dp dot with an expanding ring for live values. The ring reads
// the single shared controller, so no per-dot ticker exists. Stale and
// scheduled values show a still dot in their own colour.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_style.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/models/certainty.dart';

/// Dot that signals a live position, or a still dot otherwise.
class LiveDot extends StatelessWidget {
  /// Creates a dot.
  const LiveDot({
    required this.certainty,
    this.size = 8,
    this.animation,
    super.key,
  });

  /// Which certainty to draw.
  final Certainty certainty;

  /// Diameter of the solid dot in dp.
  final double size;

  /// Overrides the shared controller, for tests.
  final AnimationController? animation;

  @override
  Widget build(BuildContext context) {
    final CertaintyStyle style = styleOf(context, certainty);
    final AnimationController? controller =
        animation ?? LivePulseScope.maybeOf(context);
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool live = certainty == Certainty.live;
    final bool pulse = live && controller != null && !reduce;

    return Semantics(
      label: style.label,
      excludeSemantics: true,
      child: Center(
        child: SizedBox(
          width: size * 3,
          height: size * 3,
          child: AnimatedBuilder(
            animation: pulse
                ? controller
                : const AlwaysStoppedAnimation<double>(0),
            builder: (BuildContext context, Widget? child) {
              final double t = pulse ? controller.value : 0;
              return CustomPaint(
                size: Size.square(size * 3),
                painter: LiveDotPainter(
                  color: style.graphic,
                  radius: size / 2,
                  pulseColor: style.graphic.withValues(alpha: 0.3 * (1 - t)),
                  pulseRadius: size / 2 + t * size * 1.5,
                  filled: live,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the dot and its ring.
class LiveDotPainter extends CustomPainter {
  /// Creates the painter.
  const LiveDotPainter({
    required this.color,
    required this.radius,
    required this.pulseColor,
    required this.pulseRadius,
    required this.filled,
  });

  /// Dot colour.
  final Color color;

  /// Dot radius in dp.
  final double radius;

  /// Ring colour, already carrying its alpha.
  final Color pulseColor;

  /// Ring radius in dp.
  final double pulseRadius;

  /// Whether the dot is filled (live) or hollow (other certainties).
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    if (pulseRadius > radius) {
      canvas.drawCircle(center, pulseRadius, Paint()..color = pulseColor);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = radius * 0.5,
    );
  }

  @override
  bool shouldRepaint(LiveDotPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.pulseColor != pulseColor ||
        oldDelegate.pulseRadius != pulseRadius ||
        oldDelegate.filled != filled;
  }
}

/// Duration used by the dot ring, kept next to the painter for tests.
Duration get liveDotDuration => Motion.pulse;

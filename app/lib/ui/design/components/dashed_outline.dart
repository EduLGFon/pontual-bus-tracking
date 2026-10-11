// Dashed outline: rounded rect drawn with a dashed path. Used by the
// predicted certainty, which must never look solid like a live value.
// See docs/ui/UI_SPEC.md 3.
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed rounded rectangle.
class DashedOutline extends CustomPainter {
  /// Creates the painter.
  const DashedOutline({
    required this.color,
    required this.radius,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  /// Outline colour.
  final Color color;

  /// Corner radius in logical pixels.
  final double radius;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// Dash length in logical pixels.
  final double dash;

  /// Gap length in logical pixels.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    canvas.drawPath(_dash(path, dash, gap), paint);
  }

  @override
  bool shouldRepaint(DashedOutline oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

/// Builds a dashed copy of [source] by walking its metrics and emitting
/// alternating dash and gap segments.
Path _dash(Path source, double dash, double gap) {
  final Path out = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    double distance = 0;
    while (distance < metric.length) {
      final double next = math.min(distance + dash, metric.length);
      out.addPath(metric.extractPath(distance, next), Offset.zero);
      distance = next + gap;
    }
  }
  return out;
}

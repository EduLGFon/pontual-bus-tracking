// PredictedPath: dashed polyline from the last real fix along the route.
// The map caller projects route points into the marker layer and passes
// them here; the gallery passes fake offsets. Flagged off with predictions.
// See docs/ui/UI_SPEC.md 13.1.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_style.dart';
import 'package:pontual/ui/models/certainty.dart';

/// Dashed prediction path in an explicit coordinate space.
class PredictedPath extends StatelessWidget {
  /// Creates the path.
  const PredictedPath({required this.points, this.height = 72, super.key});

  /// Points in the painter box. Two or more draws; fewer renders nothing.
  final List<Offset> points;

  /// Box height.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    final CertaintyStyle style = styleOf(context, Certainty.predicted);
    return Semantics(
      label: 'Trajeto previsto',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _DashedPathPainter(points: points, color: style.graphic),
      ),
    );
  }
}

/// Paints one dashed polyline, no saveLayer, no shadow.
class _DashedPathPainter extends CustomPainter {
  /// Creates the painter.
  const _DashedPathPainter({required this.points, required this.color});

  /// Polyline points.
  final List<Offset> points;

  /// Dash colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const double dash = 6;
    const double gap = 4;
    for (int i = 0; i + 1 < points.length; i++) {
      _dashedSegment(canvas, points[i], points[i + 1], paint, dash, gap);
    }
  }

  void _dashedSegment(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dash,
    double gap,
  ) {
    final double length = (to - from).distance;
    if (length <= 0) {
      return;
    }
    final Offset dir = (to - from) / length;
    double drawn = 0;
    while (drawn < length) {
      final double end = (drawn + dash).clamp(0.0, length);
      canvas.drawLine(from + dir * drawn, from + dir * end, paint);
      drawn = end + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedPathPainter old) =>
      old.points != points || old.color != color;
}

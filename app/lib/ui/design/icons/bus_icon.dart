// Bus icon, front view. Custom-painted so it stays crisp at any size and
// costs nothing at runtime. One rounded stroke weight, matching the other
// domain icons. See docs/ui/UI_SPEC.md 4.5.
import 'package:flutter/material.dart';

/// Paints a bus seen from the front: body, windscreen, two lights.
class BusIconPainter extends CustomPainter {
  /// Creates the painter.
  const BusIconPainter({
    required this.color,
    this.strokeWidth = 1.75,
    this.filled = true,
  });

  /// Line colour.
  final Color color;

  /// Stroke width in the icon's own 24x24 coordinate space.
  final double strokeWidth;

  /// When true the body is filled, otherwise outlined.
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint body = Paint()
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final Rect bodyRect = Rect.fromLTWH(3 * s, 2 * s, 18 * s, 15 * s);
    final RRect bodyShape = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(4 * s),
    );
    canvas.drawRRect(bodyShape, body);

    canvas.drawRect(
      Rect.fromLTWH(6.5 * s, 5 * s, 11 * s, 6 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
    canvas.drawLine(Offset(12 * s, 5 * s), Offset(12 * s, 11 * s), stroke);
    canvas.drawLine(Offset(6 * s, 14.5 * s), Offset(18 * s, 14.5 * s), stroke);
    canvas.drawCircle(Offset(7 * s, 19 * s), 1.1 * s, Paint()..color = color);
    canvas.drawCircle(Offset(17 * s, 19 * s), 1.1 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BusIconPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.filled != filled;
  }
}

/// Widget wrapper around [BusIconPainter].
class BusIcon extends StatelessWidget {
  /// Creates the icon at [size] dp.
  const BusIcon({
    this.size = 24,
    required this.color,
    this.filled = true,
    super.key,
  });

  /// Width and height in logical pixels.
  final double size;

  /// Icon colour.
  final Color color;

  /// Whether the body is filled.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: BusIconPainter(color: color, filled: filled),
      ),
    );
  }
}

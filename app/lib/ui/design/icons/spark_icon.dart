// Spark icon used by the predicted certainty. Four points, no fill, so it
// reads as an estimate rather than a measurement.
// See docs/ui/UI_SPEC.md 4.5.
import 'package:flutter/material.dart';

/// Paints the prediction spark.
class SparkIconPainter extends CustomPainter {
  /// Creates the painter.
  const SparkIconPainter(this.color);

  /// Icon colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path()
      ..moveTo(12 * s, 3 * s)
      ..lineTo(14.5 * s, 10 * s)
      ..lineTo(21.5 * s, 12 * s)
      ..lineTo(14.5 * s, 14 * s)
      ..lineTo(12 * s, 21 * s)
      ..lineTo(9.5 * s, 14 * s)
      ..lineTo(2.5 * s, 12 * s)
      ..lineTo(9.5 * s, 10 * s)
      ..close();
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(SparkIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Widget wrapper around [SparkIconPainter].
class SparkIcon extends StatelessWidget {
  /// Creates the icon at [size] dp.
  const SparkIcon({this.size = 16, required this.color, super.key});

  /// Width and height in logical pixels.
  final double size;

  /// Icon colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: SparkIconPainter(color)),
    );
  }
}

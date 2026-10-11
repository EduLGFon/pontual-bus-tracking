// Live waves icon: a solid dot with two emitting arcs. Used wherever the
// UI says "this is measured right now".
// See docs/ui/UI_SPEC.md 4.5.
import 'package:flutter/material.dart';

/// Paints the live signal icon.
class LiveWavesIconPainter extends CustomPainter {
  /// Creates the painter.
  const LiveWavesIconPainter(this.color);

  /// Icon colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint dot = Paint()..color = color;
    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(6 * s, 12 * s), 3 * s, dot);
    for (final double r in <double>[7.5, 11.5]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(6 * s, 12 * s), radius: r * s),
        -0.9,
        1.8,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(LiveWavesIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Widget wrapper around [LiveWavesIconPainter].
class LiveWavesIcon extends StatelessWidget {
  /// Creates the icon at [size] dp.
  const LiveWavesIcon({this.size = 16, required this.color, super.key});

  /// Width and height in logical pixels.
  final double size;

  /// Icon colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: LiveWavesIconPainter(color)),
    );
  }
}

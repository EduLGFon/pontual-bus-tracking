// Route and terminal glyphs. Both are simple path drawings so the line
// screen can label origin chips and terminals without an icon font.
// See docs/ui/UI_SPEC.md 4.5.
import 'package:flutter/material.dart';

/// Paints a route: a start dot, a winding line, a flag at the end.
class RouteIconPainter extends CustomPainter {
  /// Creates the painter.
  const RouteIconPainter(this.color);

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
    final Paint dot = Paint()..color = color;

    canvas.drawCircle(Offset(5 * s, 18 * s), 2.2 * s, dot);

    final Path path = Path()
      ..moveTo(5 * s, 18 * s)
      ..lineTo(5 * s, 11 * s)
      ..cubicTo(5 * s, 7 * s, 12 * s, 12 * s, 12 * s, 8 * s)
      ..lineTo(12 * s, 4 * s);
    canvas.drawPath(path, stroke);

    canvas.drawLine(Offset(12 * s, 3 * s), Offset(19 * s, 3 * s), stroke);
    canvas.drawLine(Offset(19 * s, 3 * s), Offset(19 * s, 9 * s), stroke);
    canvas.drawLine(Offset(19 * s, 9 * s), Offset(13.5 * s, 9 * s), stroke);
  }

  @override
  bool shouldRepaint(RouteIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Widget wrapper around [RouteIconPainter].
class RouteIcon extends StatelessWidget {
  /// Creates the icon at [size] dp.
  const RouteIcon({this.size = 24, required this.color, super.key});

  /// Width and height in logical pixels.
  final double size;

  /// Icon colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: RouteIconPainter(color)),
    );
  }
}

/// Paints a terminal stop sign: a rounded post with a horizontal bar.
class TerminalIconPainter extends CustomPainter {
  /// Creates the painter.
  const TerminalIconPainter(this.color);

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

    canvas.drawLine(Offset(12 * s, 3 * s), Offset(12 * s, 21 * s), stroke);
    canvas.drawLine(Offset(7 * s, 4 * s), Offset(17 * s, 4 * s), stroke);
    canvas.drawLine(Offset(9 * s, 21 * s), Offset(15 * s, 21 * s), stroke);
    canvas.drawCircle(Offset(12 * s, 8 * s), 1.6 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(TerminalIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Widget wrapper around [TerminalIconPainter].
class TerminalIcon extends StatelessWidget {
  /// Creates the icon at [size] dp.
  const TerminalIcon({this.size = 24, required this.color, super.key});

  /// Width and height in logical pixels.
  final double size;

  /// Icon colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: TerminalIconPainter(color)),
    );
  }
}

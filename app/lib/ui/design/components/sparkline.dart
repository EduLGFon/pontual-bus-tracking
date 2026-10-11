// Sparkline: 7-12 bars of delay history drawn with a CustomPainter.
// Flagged off with the reliability UI; the gallery shows it with fake
// data. See docs/ui/UI_SPEC.md 5 and 13.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';

/// Bar sparkline for aggregated delay history.
class Sparkline extends StatelessWidget {
  /// Creates the sparkline.
  const Sparkline({required this.bars, this.height = 32, super.key});

  /// Bar heights 0 to 1, oldest first. Empty renders nothing.
  final List<double> bars;

  /// Chart height.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: 'Histórico de atrasos',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparkBarsPainter(bars: bars, fill: context.colors.primary),
      ),
    );
  }
}

/// Paints one rounded bar per value, no saveLayer, no shadow.
class _SparkBarsPainter extends CustomPainter {
  /// Creates the painter.
  const _SparkBarsPainter({required this.bars, required this.fill});

  /// Values 0 to 1.
  final List<double> bars;

  /// Bar fill.
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = bars.length;
    const double gap = 3;
    final double slot = size.width / n;
    final double width = (slot - gap).clamp(2.0, 12.0);
    final Paint paint = Paint()..color = fill;
    for (int i = 0; i < n; i++) {
      final double v = bars[i].clamp(0.0, 1.0);
      final double h = (size.height * v).clamp(2.0, size.height);
      final double x = i * slot + (slot - width) / 2;
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, width, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkBarsPainter old) =>
      old.bars != bars || old.fill != fill;
}

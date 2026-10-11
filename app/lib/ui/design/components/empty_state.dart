// EmptyState: a small vector illustration drawn from shapes, a title, one
// sentence and one action. Never an image file.
// See docs/ui/UI_SPEC.md 5 and 10.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Kinds of illustration. Each is 2 to 4 shapes.
enum EmptyArt {
  /// Bus, for "nothing sharing right now".
  bus,

  /// Magnifier, for "nothing found".
  search,

  /// Map pin, for "line not found".
  pin,

  /// Cloud, for offline and server states.
  cloud,

  /// Wrench, for maintenance.
  wrench,
}

/// Designed empty state.
class EmptyState extends StatelessWidget {
  /// Creates the empty state.
  const EmptyState({
    required this.title,
    required this.message,
    this.art = EmptyArt.bus,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  /// Title in pt-BR.
  final String title;

  /// One sentence that explains.
  final String message;

  /// Which illustration to draw.
  final EmptyArt art;

  /// Optional primary action.
  final String? actionLabel;

  /// Called on the primary action.
  final VoidCallback? onAction;

  /// Optional secondary action.
  final String? secondaryLabel;

  /// Called on the secondary action.
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$title. $message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: EmptyArtPainter(
                art: art,
                color: colors.inkMuted,
                accent: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: Space.x4),
          Text(title, style: context.text.title, textAlign: TextAlign.center),
          const SizedBox(height: Space.x2),
          Text(message, style: context.text.body, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: Space.x6),
            Pressable(
              onTap: onAction,
              semanticLabel: actionLabel,
              borderRadius: Radii.pill,
              child: Container(
                height: Sizes.button,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: Space.x6),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  actionLabel!,
                  style: context.text.label.copyWith(color: colors.onPrimary),
                ),
              ),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...<Widget>[
            const SizedBox(height: Space.x2),
            Pressable(
              onTap: onSecondary,
              semanticLabel: secondaryLabel,
              borderRadius: Radii.pill,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.x3,
                  vertical: Space.x2,
                ),
                child: Text(
                  secondaryLabel!,
                  style: context.text.label.copyWith(color: colors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paints the illustrations with 2 to 4 shapes.
class EmptyArtPainter extends CustomPainter {
  /// Creates the painter.
  const EmptyArtPainter({
    required this.art,
    required this.color,
    required this.accent,
  });

  /// Which illustration to draw.
  final EmptyArt art;

  /// Base stroke colour.
  final Color color;

  /// Accent fill colour.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 96;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()..color = accent;

    switch (art) {
      case EmptyArt.bus:
        final RRect body = RRect.fromRectAndRadius(
          Rect.fromLTWH(18 * s, 26 * s, 60 * s, 42 * s),
          Radius.circular(10 * s),
        );
        canvas.drawRRect(body, stroke);
        canvas.drawRect(Rect.fromLTWH(28 * s, 36 * s, 40 * s, 18 * s), stroke);
        canvas.drawCircle(Offset(32 * s, 74 * s), 5 * s, fill);
        canvas.drawCircle(Offset(64 * s, 74 * s), 5 * s, fill);
      case EmptyArt.search:
        canvas.drawCircle(Offset(42 * s, 42 * s), 20 * s, stroke);
        canvas.drawLine(Offset(57 * s, 57 * s), Offset(78 * s, 78 * s), stroke);
      case EmptyArt.pin:
        final Path pin = Path()
          ..moveTo(48 * s, 18 * s)
          ..cubicTo(64 * s, 18 * s, 74 * s, 30 * s, 74 * s, 44 * s)
          ..cubicTo(74 * s, 64 * s, 48 * s, 82 * s, 48 * s, 82 * s)
          ..cubicTo(48 * s, 82 * s, 22 * s, 64 * s, 22 * s, 44 * s)
          ..cubicTo(22 * s, 30 * s, 32 * s, 18 * s, 48 * s, 18 * s);
        canvas.drawPath(pin, stroke);
        canvas.drawCircle(Offset(48 * s, 44 * s), 8 * s, fill);
      case EmptyArt.cloud:
        final Path cloud = Path()
          ..moveTo(28 * s, 62 * s)
          ..cubicTo(18 * s, 62 * s, 18 * s, 40 * s, 32 * s, 40 * s)
          ..cubicTo(34 * s, 24 * s, 60 * s, 22 * s, 66 * s, 38 * s)
          ..cubicTo(80 * s, 38 * s, 80 * s, 62 * s, 68 * s, 62 * s);
        canvas.drawPath(cloud, stroke);
        canvas.drawLine(Offset(36 * s, 74 * s), Offset(60 * s, 74 * s), stroke);
      case EmptyArt.wrench:
        canvas.drawCircle(Offset(38 * s, 38 * s), 12 * s, stroke);
        canvas.drawLine(Offset(46 * s, 46 * s), Offset(76 * s, 76 * s), stroke);
        canvas.drawLine(Offset(64 * s, 76 * s), Offset(76 * s, 64 * s), stroke);
    }
  }

  @override
  bool shouldRepaint(EmptyArtPainter oldDelegate) {
    return oldDelegate.art != art ||
        oldDelegate.color != color ||
        oldDelegate.accent != accent;
  }
}

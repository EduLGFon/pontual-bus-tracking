// Surface card: the tonal layer used by rows and panels. Depth comes from
// the surface colour plus a 1 px hairline, never from a shadow.
// See docs/ui/UI_SPEC.md 4.3 and 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// A card with a hairline border and optional tap target.
class SurfaceCard extends StatelessWidget {
  /// Creates a card.
  const SurfaceCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Space.x4),
    this.borderRadius = Radii.l,
    this.selected = false,
    this.semanticLabel,
    this.sunken = false,
    super.key,
  });

  /// Card content.
  final Widget child;

  /// Called on tap. Null makes the card inert.
  final VoidCallback? onTap;

  /// Called on long press.
  final VoidCallback? onLongPress;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Corner radius.
  final double borderRadius;

  /// Shows the selected tint, used by favourites and filters.
  final bool selected;

  /// Screen-reader sentence for the whole row.
  final String? semanticLabel;

  /// Uses the sunken surface instead of the card surface.
  final bool sunken;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget card = Container(
      decoration: BoxDecoration(
        color: sunken ? colors.surfaceSunken : colors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: selected ? colors.primary : colors.line),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null && onLongPress == null) {
      return card;
    }
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      borderRadius: borderRadius,
      child: card,
    );
  }
}

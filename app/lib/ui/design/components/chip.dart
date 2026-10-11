// Chips and filter chips. Pill, 36 dp tall with a 48 dp hit area, sunken
// fill; the selected state fills with the primary colour.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// A pill chip.
class Chip extends StatelessWidget {
  /// Creates a chip.
  const Chip({
    required this.label,
    this.onTap,
    this.selected = false,
    this.leading,
    this.dotColor,
    this.semanticLabel,
    this.compact = false,
    super.key,
  });

  /// Chip label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Selected state, filled with the primary colour.
  final bool selected;

  /// Optional leading icon.
  final IconData? leading;

  /// Optional leading dot colour, for line colour dots.
  final Color? dotColor;

  /// Screen-reader label when it differs from [label].
  final String? semanticLabel;

  /// Uses a 32 dp height for dense rows, still with a 48 dp hit area.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fill = selected ? colors.primary : colors.surfaceSunken;
    final Color labelColor = selected ? colors.onPrimary : colors.ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      borderRadius: Radii.pill,
      child: Container(
        height: compact ? 32 : Sizes.chip,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (dotColor != null) ...<Widget>[
              Container(
                width: Space.x2,
                height: Space.x2,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.x2),
            ],
            if (leading != null) ...<Widget>[
              Icon(leading, size: 18, color: labelColor),
              const SizedBox(width: Space.x1),
            ],
            Text(
              label,
              style: PontualText.label.copyWith(color: labelColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

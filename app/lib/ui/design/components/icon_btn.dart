// Icon button with a 48 dp hit area and a circular pressed tint. Always
// carries a semantic label, so an icon never stands alone.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Circular icon button.
class IconBtn extends StatelessWidget {
  /// Creates an icon button.
  const IconBtn({
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.size = hitTarget,
    this.iconSize = 24,
    this.selected = false,
    this.tooltip,
    this.filled = false,
    super.key,
  });

  /// Icon shown in the middle.
  final IconData icon;

  /// Screen-reader label, also used as the web tooltip.
  final String semanticLabel;

  /// Called on tap. Null disables the button.
  final VoidCallback? onTap;

  /// Hit area in dp.
  final double size;

  /// Icon size in dp.
  final double iconSize;

  /// Shows the selected tint (star on, follow on).
  final bool selected;

  /// Optional tooltip; falls back to [semanticLabel].
  final String? tooltip;

  /// Uses a sunken filled circle background.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color iconColor = selected ? colors.primary : colors.ink;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      borderRadius: Radii.pill,
      child: Tooltip(
        message: tooltip ?? semanticLabel,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? colors.surfaceSunken
                : selected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surface.withValues(alpha: 0),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}

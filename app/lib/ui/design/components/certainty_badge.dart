// CertaintyBadge: the only place certainty is drawn. Icon plus label in a
// pill, plus a shape (solid dot, dashed outline, clock, amber ring) so the
// information never travels by colour alone.
// See docs/ui/UI_SPEC.md 3 and 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_style.dart';
import 'package:pontual/ui/design/components/dashed_outline.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/models/certainty.dart';

/// Pill that states how much the UI trusts the value next to it.
class CertaintyBadge extends StatelessWidget {
  /// Creates a badge.
  const CertaintyBadge({
    required this.certainty,
    this.compact = false,
    this.onInfo,
    super.key,
  });

  /// Which certainty to draw.
  final Certainty certainty;

  /// Icon only, with a semantics label.
  final bool compact;

  /// Optional info affordance opening "Como calculamos isso?".
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final CertaintyStyle style = styleOf(context, certainty);
    final Color labelColor = style.text;
    final Widget content = compact
        ? Icon(style.icon, size: 14, color: style.graphic)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(style.icon, size: 14, color: style.graphic),
              const SizedBox(width: Space.x1),
              Flexible(
                child: Text(
                  style.label,
                  style: PontualText.caption.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final Widget pill = CustomPaint(
      painter: DashedOutline(
        color: labelColor,
        radius: Radii.pill,
        strokeWidth: 1,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Space.x2 : Space.x3,
          vertical: Space.x1,
        ),
        constraints: const BoxConstraints(minHeight: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: labelColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: style.dashed
              ? Border.all(color: labelColor.withValues(alpha: 0))
              : Border.all(color: labelColor.withValues(alpha: 0.35)),
        ),
        child: content,
      ),
    );

    if (onInfo == null) {
      return Semantics(label: style.label, excludeSemantics: true, child: pill);
    }
    return Semantics(
      label: style.label,
      button: true,
      child: GestureDetector(
        onTap: onInfo,
        behavior: HitTestBehavior.opaque,
        child: pill,
      ),
    );
  }
}

// Ghost link: text-only action with a 48 dp hit area, used as the trailing
// action of section headers and list rows.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// Text-only action.
class GhostLink extends StatelessWidget {
  /// Creates the link.
  const GhostLink({
    required this.label,
    this.onTap,
    this.icon,
    this.color,
    this.minSize = 48,
    super.key,
  });

  /// Label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Optional trailing icon.
  final IconData? icon;

  /// Label colour.
  final Color? color;

  /// Hit area in dp.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: 999,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                style: PontualText.label.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (icon != null) ...<Widget>[
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

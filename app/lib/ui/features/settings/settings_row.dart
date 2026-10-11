// Settings row: the list row shared by the settings entries, the privacy
// center and the about screen. Icon plus label (plus optional subtitle),
// a trailing chevron, a 48 dp hit area, and a pt-BR semantics label, so an
// icon never stands alone. See docs/ui/UI_SPEC.md 7.8.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Settings list row.
class SettingsRow extends StatelessWidget {
  /// Creates the row for [label].
  const SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Row label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  /// Optional second line under the label.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.l,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x3),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: context.colors.inkMuted),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: context.text.body),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: Space.x1),
                    Text(subtitle!, style: context.text.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.x2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.inkSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

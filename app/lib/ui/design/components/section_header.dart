// Section header with an optional trailing ghost action.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Title of a section, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  /// Creates a header.
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.topSpacing = Space.x6,
    this.subtitle,
    super.key,
  });

  /// Section title in pt-BR.
  final String title;

  /// Trailing action label, for example "Ver todas".
  final String? actionLabel;

  /// Called when the trailing action is tapped.
  final VoidCallback? onAction;

  /// Spacing above the header.
  final double topSpacing;

  /// Optional line under the title.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: Space.x3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.text.title),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: Space.x1),
                  Text(subtitle!, style: context.text.caption),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            GhostLink(label: actionLabel!, onTap: onAction),
        ],
      ),
    );
  }
}

// Shared settings rows: one left edge, one row height, one list.
// `SettingsSection` renders the small muted header with an optional footer.
// `SettingsTile` renders either a navigation row (chevron) or an immediate
// switch row. The two constructors keep the trailing control unambiguous:
// a row never mixes a switch with a chevron.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Settings section with a small muted header and an optional footer.
class SettingsSection extends StatelessWidget {
  /// Creates a section with [title] and [children] rows.
  const SettingsSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.footer,
    this.topSpacing = Space.x6,
    super.key,
  });

  /// Section title in pt-BR.
  final String title;

  /// Rows of the section.
  final List<Widget> children;

  /// One-line summary under the title, if any.
  final String? subtitle;

  /// Small print under the rows, if any.
  final String? footer;

  /// Space above the header.
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: context.text.label.copyWith(color: colors.inkMuted),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: Space.x1),
            Text(
              subtitle!,
              style: context.text.caption.copyWith(color: colors.inkMuted),
            ),
          ],
          const SizedBox(height: Space.x2),
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: colors.line),
          ],
          if (footer != null) ...<Widget>[
            const SizedBox(height: Space.x2),
            Text(
              footer!,
              style: context.text.caption.copyWith(color: colors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Trailing control of a [SettingsTile].
enum _TrailingKind {
  /// Chevron for rows that open another page.
  chevron,

  /// Switch for rows with an immediate effect.
  toggle,
}

/// One settings row: optional leading icon, title, optional description,
/// and a trailing switch, chevron or value. Minimum 56 dp tall, 72 dp
/// with a description. The whole row is the tap target.
class SettingsTile extends StatelessWidget {
  /// Creates a navigation row that opens another page.
  const SettingsTile.chevron({
    required this.title,
    required this.onTap,
    this.icon,
    this.description,
    this.semanticLabel,
    super.key,
  }) : _kind = _TrailingKind.chevron,
       value = false,
       onChanged = null,
       trailingValue = null;

  /// Creates a switch row with an immediate effect.
  const SettingsTile.toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.description,
    super.key,
  }) : _kind = _TrailingKind.toggle,
       onTap = null,
       semanticLabel = null,
       trailingValue = null;

  /// Creates a value row that opens another page or dialog.
  const SettingsTile.value({
    required this.title,
    required this.onTap,
    required this.trailingValue,
    this.icon,
    this.description,
    this.semanticLabel,
    super.key,
  }) : _kind = _TrailingKind.chevron,
       value = false,
       onChanged = null;

  /// Row title in pt-BR.
  final String title;

  /// Leading icon, if any.
  final IconData? icon;

  /// Optional second line under the title.
  final String? description;

  /// Called on tap for navigation and value rows.
  final VoidCallback? onTap;

  /// Current value for switch rows.
  final bool value;

  /// Called with the new value for switch rows.
  final ValueChanged<bool>? onChanged;

  /// Screen-reader label for navigation rows, defaults to [title].
  final String? semanticLabel;

  /// Trailing text for value rows.
  final String? trailingValue;

  /// Which trailing control to render.
  final _TrailingKind _kind;

  @override
  Widget build(BuildContext context) {
    if (_kind == _TrailingKind.toggle) {
      return _toggleRow(context);
    }
    return _navRow(context);
  }

  /// Switch row exposed as a single switch to screen readers.
  Widget _toggleRow(BuildContext context) {
    final colors = context.colors;
    final String state = value ? 'ativado' : 'desativado';
    final String label = description == null || description!.isEmpty
        ? '$title, interruptor, $state'
        : '$title, interruptor, $state. $description';
    final double minHeight = description == null ? 56 : 72;
    return Semantics(
      label: label,
      toggled: value,
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onChanged?.call(!value),
        semanticButton: false,
        borderRadius: Radii.l,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: colors.inkMuted),
                  const SizedBox(width: Space.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: context.text.body),
                      if (description != null) ...<Widget>[
                        const SizedBox(height: Space.x1),
                        Text(
                          description!,
                          style: context.text.caption.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                ExcludeSemantics(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigation row with a chevron or a trailing value.
  Widget _navRow(BuildContext context) {
    final colors = context.colors;
    final double minHeight = description == null ? 56 : 72;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? title,
      borderRadius: Radii.l,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: colors.inkMuted),
                const SizedBox(width: Space.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: context.text.body),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: Space.x1),
                      Text(
                        description!,
                        style: context.text.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              if (trailingValue != null)
                Text(
                  trailingValue!,
                  style: context.text.label.copyWith(color: colors.inkMuted),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.inkSubtle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Buttons. Pill shapes, one primary action per screen, loading shown as a
// static label change instead of a spinner, disabled at 38 percent alpha.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/design/components/pressable.dart';

/// The pill button family. Labels come from the strings file.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary button.
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
    this.loading = false,
    this.fullWidth = true,
    this.semanticLabel,
    super.key,
  });

  /// Action label in pt-BR.
  final String label;

  /// Called on tap. Null or [loading] disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Uses the 48 dp height instead of 56 dp.
  final bool compact;

  /// Shows a static "starting" label and blocks further taps.
  final bool loading;

  /// Stretches to the available width.
  final bool fullWidth;

  /// Screen-reader label when it differs from [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool enabled = onPressed != null && !loading;
    final Color fill = enabled
        ? colors.primary
        : colors.primary.withValues(alpha: 0.38);
    final Color labelColor = enabled
        ? colors.onPrimary
        : colors.onPrimary.withValues(alpha: 0.38);
    final Widget content = _ButtonBody(
      label: label,
      labelStyle: PontualText.label.copyWith(color: labelColor),
      icon: icon,
      iconColor: labelColor,
    );
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: semanticLabel ?? label,
      borderRadius: Radii.pill,
      minSize: 0,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: compact ? Sizes.buttonCompact : Sizes.button,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Space.x6),
        child: content,
      ),
    );
  }
}

/// Secondary button: sunken fill with a hairline border.
class SecondaryButton extends StatelessWidget {
  /// Creates a secondary button.
  const SecondaryButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
    this.fullWidth = true,
    super.key,
  });

  /// Action label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Uses the 48 dp height instead of 56 dp.
  final bool compact;

  /// Stretches to the available width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color labelColor = colors.ink;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      borderRadius: Radii.pill,
      minSize: 0,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: compact ? Sizes.buttonCompact : Sizes.button,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: colors.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Space.x6),
        child: _ButtonBody(
          label: label,
          labelStyle: PontualText.label.copyWith(color: labelColor),
          icon: icon,
          iconColor: labelColor,
        ),
      ),
    );
  }
}

/// Ghost button: text only, with a 48 dp hit area.
class GhostButton extends StatelessWidget {
  /// Creates a ghost button.
  const GhostButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    super.key,
  });

  /// Action label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Label colour, defaults to the primary token.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color labelColor = color ?? colors.primary;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      borderRadius: Radii.pill,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: labelColor),
              const SizedBox(width: Space.x1),
            ],
            Text(label, style: PontualText.label.copyWith(color: labelColor)),
          ],
        ),
      ),
    );
  }
}

/// Danger button: 12 percent danger fill with the danger label.
class DangerButton extends StatelessWidget {
  /// Creates a danger button.
  const DangerButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    super.key,
  });

  /// Action label in pt-BR.
  final String label;

  /// Called on tap.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Stretches to the available width.
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      borderRadius: Radii.pill,
      minSize: 0,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: Sizes.button,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Space.x6),
        child: _ButtonBody(
          label: label,
          labelStyle: PontualText.label.copyWith(color: colors.dangerText),
          icon: icon,
          iconColor: colors.dangerText,
        ),
      ),
    );
  }
}

/// Button body: optional icon plus label, wrapped in a fitted row.
class _ButtonBody extends StatelessWidget {
  const _ButtonBody({
    required this.label,
    required this.labelStyle,
    required this.icon,
    required this.iconColor,
  });

  /// Label text.
  final String label;

  /// Label style.
  final TextStyle labelStyle;

  /// Optional leading icon.
  final IconData? icon;

  /// Icon colour.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: Space.x2),
        ],
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

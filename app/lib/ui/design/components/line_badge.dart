// LineBadge: rounded 999 pill with the line short code, filled from the
// business category palette and with a text colour computed for contrast.
// Optional Hero tag for the line screen transition.
// See docs/ui/UI_SPEC.md 5 and docs/ui/lines-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/design/icons/bus_icon.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/models/line_vm.dart';

/// Size variants of the badge.
enum BadgeSize {
  /// 24 dp high.
  s,

  /// 28 dp high.
  m,

  /// 40 dp high.
  l,
}

/// The line colour pill.
class LineBadge extends StatelessWidget {
  /// Creates a badge.
  const LineBadge({
    required this.lineKey,
    required this.text,
    this.size = BadgeSize.m,
    this.color,
    this.category,
    this.heroTag,
    this.dimmed = false,
    super.key,
  });

  /// Builds a badge from a line view-model, resolving the business
  /// category from the line itself so every badge shares one source.
  factory LineBadge.ofLine(
    LineVM line, {
    BadgeSize size = BadgeSize.m,
    String? heroTag,
    bool dimmed = false,
  }) {
    return LineBadge(
      lineKey: line.key,
      text: line.badgeText,
      size: size,
      color: line.color,
      category: categoryFor(
        short: line.short ?? '',
        name: line.name,
        terminals: line.terminals,
        areaTags: line.areaTags,
      ),
      heroTag: heroTag,
      dimmed: dimmed,
    );
  }

  /// Stable line key used to hash the colour when no category applies.
  final String lineKey;

  /// Badge text. Empty shows a bus icon instead.
  final String text;

  /// Size variant.
  final BadgeSize size;

  /// Optional colour from data, validated before use.
  final Color? color;

  /// Business category, resolved by the factory. Null keeps the hash fallback.
  final LineCategory? category;

  /// Optional Hero tag. Never used with the map.
  final String? heroTag;

  /// Dims the fill and glyph by colour alpha for past content.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color? categoryFill = category == null
        ? null
        : categoryColorOf(category!, brightness: brightness);
    final Color resolved = lineColorOf(
      lineKey,
      brightness: brightness,
      colorValue: color ?? categoryFill,
    );
    final Color fill = dimmed ? resolved.withValues(alpha: 0.55) : resolved;
    final Color onFill = lineBadgeTextOf(resolved)
        .withValues(alpha: dimmed ? 0.55 : 1);
    final double height = switch (size) {
      BadgeSize.s => Sizes.badgeS,
      BadgeSize.m => Sizes.badgeM,
      BadgeSize.l => Sizes.badgeL,
    };
    final double fontSize = switch (size) {
      BadgeSize.s => 11,
      BadgeSize.m => 13,
      BadgeSize.l => 18,
    };
    final Widget body = Container(
      constraints: BoxConstraints(minWidth: height * 10 / 7, minHeight: height),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size == BadgeSize.s ? 6 : 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: text.isEmpty
          ? BusIcon(size: height * 0.6, color: onFill)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: PontualText.label.copyWith(
                  color: onFill,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
    final Widget badge = Semantics(
      label: text.isEmpty ? 'ônibus' : 'Linha $text',
      excludeSemantics: true,
      child: heroTag == null ? body : Hero(tag: heroTag!, child: body),
    );
    return badge;
  }
}

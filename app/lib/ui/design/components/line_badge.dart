// LineBadge: rounded 999 pill with the line short code, filled from the
// deterministic line palette and with a text colour computed for contrast.
// Optional Hero tag for the line screen transition.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
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
    this.heroTag,
    super.key,
  });

  /// Builds a badge from a line view-model.
  factory LineBadge.ofLine(
    LineVM line, {
    BadgeSize size = BadgeSize.m,
    String? heroTag,
  }) {
    return LineBadge(
      lineKey: line.key,
      text: line.badgeText,
      size: size,
      color: line.color,
      heroTag: heroTag,
    );
  }

  /// Stable line key used to hash the colour.
  final String lineKey;

  /// Badge text. Empty shows a bus icon instead.
  final String text;

  /// Size variant.
  final BadgeSize size;

  /// Optional colour from data, validated before use.
  final Color? color;

  /// Optional Hero tag. Never used with the map.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final Color fill = lineColorOf(
      lineKey,
      brightness: Theme.of(context).brightness,
      colorValue: color,
    );
    final Color onFill = lineBadgeTextOf(fill);
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

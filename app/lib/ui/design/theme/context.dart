// Context extensions that expose the token sets. `context.colors` and
// `context.text` are the only way widgets read tokens.
// See docs/ui/UI_SPEC.md 4.7.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/design/tokens/text.dart';

/// Token accessors on [BuildContext].
extension PontualContext on BuildContext {
  /// Colour tokens for the current theme.
  PontualColors get colors =>
      Theme.of(this).extension<PontualColors>() ?? PontualColors.light;

  /// Text styles.
  PontualTextStyles get text => PontualTextStyles(this);
}

/// Wrapper exposing the [PontualText] constants as theme-aware copies.
class PontualTextStyles {
  /// Creates the style accessor for [context].
  const PontualTextStyles(this.context);

  /// Context used to resolve theme-aware colours.
  final BuildContext context;

  /// The big minutes on cards and sheets.
  TextStyle get etaHero => PontualText.etaHero.withColor(ink);

  /// ETA in rows.
  TextStyle get etaLarge => PontualText.etaLarge.withColor(ink);

  /// Screen titles on Inicio.
  TextStyle get display => PontualText.display.withColor(ink);

  /// Screen and section titles.
  TextStyle get title => PontualText.title.withColor(ink);

  /// Card titles and line names.
  TextStyle get headline => PontualText.headline.withColor(ink);

  /// Main text.
  TextStyle get body => PontualText.body.withColor(ink);

  /// Emphasised body text.
  TextStyle get bodyStrong => PontualText.bodyStrong.withColor(ink);

  /// Buttons, chips, tabs.
  TextStyle get label => PontualText.label.withColor(ink);

  /// Metadata, badges, units.
  TextStyle get caption => PontualText.caption.withColor(inkMuted);

  /// Tabular clock style.
  TextStyle get clock => PontualText.clock.withColor(ink);

  /// Primary text colour.
  Color get ink => context.colors.ink;

  /// Secondary text colour.
  Color get inkMuted => context.colors.inkMuted;

  /// Tertiary text colour.
  Color get inkSubtle => context.colors.inkSubtle;
}

/// Applies [color] to a text style without losing the font features.
extension _StyledText on TextStyle {
  /// Returns a copy with [color] applied.
  TextStyle withColor(Color color) => copyWith(color: color);
}

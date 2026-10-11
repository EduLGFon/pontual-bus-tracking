// Text tokens. One bundled subsetted typeface (Manrope, SIL OFL) with a
// variable weight axis driven by FontVariation so every weight costs one
// file. Countdowns use tabular figures so digits never jitter.
// See docs/ui/UI_SPEC.md 4.2.
import 'package:flutter/painting.dart';

/// Font family registered in pubspec.yaml.
const String pontualFontFamily = 'Manrope';

/// Variable font weight axis.
const String weightAxis = 'wght';

/// The bundled subsetted font. Latin + Latin-1 + the punctuation the UI
/// uses, kept under the 70 KB budget by tools/build_fonts.sh.
class PontualText {
  /// Private constructor: this class only holds style constants.
  const PontualText._();

  /// The big minutes on cards and sheets.
  static const TextStyle etaHero = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 56,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 800)],
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// ETA in rows.
  static const TextStyle etaLarge = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 34,
    height: 36 / 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 800)],
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Screen titles on Inicio (greeting).
  static const TextStyle display = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 700)],
  );

  /// Screen and section titles.
  static const TextStyle title = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 700)],
  );

  /// Card titles and line names.
  static const TextStyle headline = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 600)],
  );

  /// Main text.
  static const TextStyle body = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 400)],
  );

  /// Emphasised body text.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 600)],
  );

  /// Buttons, chips, tabs.
  static const TextStyle label = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 600)],
  );

  /// Metadata, badges, units.
  static const TextStyle caption = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 500)],
  );

  /// Monospace-feeling tabular style for clocks. Same typeface, tabular
  /// figures on, so mm:ss width stays stable.
  static const TextStyle clock = TextStyle(
    fontFamily: pontualFontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
    fontVariations: <FontVariation>[FontVariation(weightAxis, 700)],
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

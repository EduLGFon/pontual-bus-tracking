// WCAG contrast maths in pure Dart. Used by the contrast test for every
// token pair, by the line badge colour computation, and by any future
// data-provided colour that must be validated before use.
// See docs/ui/UI_SPEC.md 4.1 and 12.6.
import 'dart:math' as math;
import 'dart:ui';

/// Relative luminance of a colour per WCAG 2.x.
double relativeLuminance(Color color) {
  return 0.2126 * _channel(color.r) +
      0.7152 * _channel(color.g) +
      0.0722 * _channel(color.b);
}

double _channel(double value) {
  return value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG contrast ratio between two colours, from 1 to 21.
double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Near-black text used on light fills.
const Color nearBlackOnFill = Color(0xFF08111A);

/// White text used on dark fills.
const Color whiteOnFill = Color(0xFFFFFFFF);

/// Picks white or near-black text for [fill], whichever has more contrast.
Color bestTextOn(Color fill) {
  return contrastRatio(fill, whiteOnFill) >=
          contrastRatio(fill, nearBlackOnFill)
      ? whiteOnFill
      : nearBlackOnFill;
}

/// Darkens [fill] until [text] reaches 4.5:1, at most 30 percent darker.
/// Used for data-provided line colours that fail contrast.
Color ensureContrast(Color fill, Color text) {
  if (contrastRatio(fill, text) >= 4.5) {
    return fill;
  }
  for (double f = 0.98; f >= 0.70; f -= 0.01) {
    final Color candidate = Color.lerp(fill, const Color(0xFF000000), 1 - f)!;
    if (contrastRatio(candidate, text) >= 4.5) {
      return candidate;
    }
  }
  return Color.lerp(fill, const Color(0xFF000000), 0.3)!;
}

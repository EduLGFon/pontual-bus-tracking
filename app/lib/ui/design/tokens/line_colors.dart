// Deterministic line colours plus the business category palette.
// The hash palette stays for unknown contexts; real lines use the category
// fills below, which carry region meaning. Both avoid pure green (live)
// and red (errors). Badge text colour is computed per fill.
// See docs/ui/UI_SPEC.md 4.1 and docs/ui/lines-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/util/contrast.dart';

/// Light theme line palette. Ordered so hashing spreads across hues.
const List<Color> linePaletteLight = <Color>[
  Color(0xFF2563EB),
  Color(0xFF027CBB),
  Color(0xFF07819E),
  Color(0xFF0F766E),
  Color(0xFFC026D3),
  Color(0xFFDB2777),
  Color(0xFFCC4D0A),
  Color(0xFF92400E),
  Color(0xFF475569),
  Color(0xFF9F1239),
];

/// Dark theme line palette. Same order, lightened so near-black badge text
/// reaches 4.5:1 on every fill.
const List<Color> linePaletteDark = <Color>[
  Color(0xFF2B73FF),
  Color(0xFF0282C4),
  Color(0xFF0787A6),
  Color(0xFF128A81),
  Color(0xFFCD29E2),
  Color(0xFFE6297D),
  Color(0xFFD6510A),
  Color(0xFFCB5913),
  Color(0xFF687D9A),
  Color(0xFFF01B56),
];

/// Palette for a brightness.
List<Color> paletteOf(Brightness brightness) {
  return brightness == Brightness.dark ? linePaletteDark : linePaletteLight;
}

/// FNV-1a 32-bit hash. Stable across platforms, unlike String.hashCode.
int stableHash(String key) {
  int hash = 0x811C9DC5;
  for (int i = 0; i < key.length; i++) {
    hash ^= key.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Fill colour for [lineKey]. [override] comes from an optional data
/// colour field and is validated for contrast before use.
Color lineColorOf(
  String lineKey, {
  required Brightness brightness,
  Color? colorValue,
}) {
  final List<Color> palette = paletteOf(brightness);
  if (colorValue != null) {
    return ensureContrast(colorValue, bestTextOn(colorValue));
  }
  return palette[stableHash(lineKey) % palette.length];
}

/// Text colour for a line badge fill, always at least 4.5:1.
Color lineBadgeTextOf(Color fill) {
  return bestTextOn(fill);
}

/// Category fills, light theme. UFES blue matches the previous blue badge;
/// Guriri yellow carries dark text; Aroeira purple is distinct from both;
/// other is neutral gray. Green and red are never used.
const Map<LineCategory, Color> lineCategoryLight = <LineCategory, Color>{
  LineCategory.ufes: Color(0xFF2563EB),
  LineCategory.guriri: Color(0xFFEAB308),
  LineCategory.aroeira: Color(0xFF7C3AED),
  LineCategory.other: Color(0xFF475569),
};

/// Category fills, dark theme. Same hues, adjusted so badge text still
/// reaches 4.5:1 in dark mode.
const Map<LineCategory, Color> lineCategoryDark = <LineCategory, Color>{
  LineCategory.ufes: Color(0xFF2B73FF),
  LineCategory.guriri: Color(0xFFFACC15),
  LineCategory.aroeira: Color(0xFFA78BFA),
  LineCategory.other: Color(0xFF687D9A),
};

/// Fill colour of a [category] for [brightness].
Color categoryColorOf(LineCategory category, {required Brightness brightness}) {
  return brightness == Brightness.dark
      ? lineCategoryDark[category]!
      : lineCategoryLight[category]!;
}

/// Parses `#RRGGBB` or `RRGGBB`. Null on anything else.
Color? parseHexColor(String value) {
  final String hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length != 6) {
    return null;
  }
  final int? rgb = int.tryParse(hex, radix: 16);
  if (rgb == null) {
    return null;
  }
  return Color(0xFF000000 | rgb);
}

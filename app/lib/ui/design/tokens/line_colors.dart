// Deterministic line colours. A stable line key hashes into a curated
// 10-colour palette that excludes pure green (reserved for live) and
// indigo/violet (reserved for predicted). Badge text colour is computed
// per fill and both themes have their own palette.
// See docs/ui/UI_SPEC.md 4.1.
import 'package:flutter/material.dart';
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

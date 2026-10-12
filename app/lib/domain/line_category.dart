// Line categories: region and destination colors with business meaning.
// Priority: UFES/IFES first, then Guriri, then region, else neutral gray.
// Assignment is by explicit line number map plus a text fallback for lines
// not in the map. No backend change; a data field would be better long term.
// See lines-screen.md section 4C.
library;

/// Business category of a line, driving badge color and list grouping.
enum LineCategory {
  /// Any line reaching UFES/IFES. Blue tag.
  ufes,

  /// Lines reaching Guriri without reaching UFES. Yellow tag.
  guriri,

  /// Aroeira region lines. Purple tag.
  aroeira,

  /// Unclassified lines. Neutral gray, listed for owner assignment.
  other,
}

/// Explicit assignment by line short code (number on the badge).
/// Known lines from the brief. Line 23 is an assumption (Santo Antonio /
/// Guriri / Expresso mentions Guriri): reported as needing confirmation.
const Map<String, LineCategory> lineCategoryByShort = <String, LineCategory>{
  '66': LineCategory.ufes,
  '62': LineCategory.ufes,
  '60': LineCategory.ufes,
  '64': LineCategory.ufes,
  '701': LineCategory.guriri,
  '70': LineCategory.guriri,
  '23': LineCategory.guriri,
  '13': LineCategory.aroeira,
  '10': LineCategory.aroeira,
};

/// pt-BR label of a category, shown as section header and in semantics.
String lineCategoryLabel(LineCategory category) {
  return switch (category) {
    LineCategory.ufes => 'UFES / IFES',
    LineCategory.guriri => 'Guriri',
    LineCategory.aroeira => 'Aroeira',
    LineCategory.other => 'Outras',
  };
}

/// Sort order of categories: UFES first, Guriri second, regions alphabetically,
/// other last. With a single region today this is ufes, guriri, aroeira, other.
int lineCategoryOrder(LineCategory category) {
  return switch (category) {
    LineCategory.ufes => 0,
    LineCategory.guriri => 1,
    LineCategory.aroeira => 2,
    LineCategory.other => 3,
  };
}

/// Category of a line. Explicit map wins; otherwise match normalized tokens
/// in name, terminals and tags: ufes/ifes, then guriri, then aroeira.
/// Unknown lines return [LineCategory.other] and never throw.
LineCategory categoryFor({
  required String short,
  required String name,
  required List<String> terminals,
  List<String> areaTags = const <String>[],
}) {
  final LineCategory? mapped = lineCategoryByShort[short.trim()];
  if (mapped != null) {
    return mapped;
  }
  final String haystack = <String>[
    name,
    ...terminals,
    ...areaTags,
  ].map(_normalize).join(' ');
  if (haystack.contains('ufes') || haystack.contains('ifes')) {
    return LineCategory.ufes;
  }
  if (haystack.contains('guriri')) {
    return LineCategory.guriri;
  }
  if (haystack.contains('aroeira')) {
    return LineCategory.aroeira;
  }
  return LineCategory.other;
}

/// Lowercase accent-insensitive normalization for pt-BR place names.
String _normalize(String input) {
  final StringBuffer out = StringBuffer();
  for (final int rune in input.toLowerCase().runes) {
    out.write(_diacritics[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

/// Latin letters with diacritics that appear in São Mateus place names.
const Map<int, String> _diacritics = <int, String>{
  0xE0: 'a',
  0xE1: 'a',
  0xE2: 'a',
  0xE3: 'a',
  0xE4: 'a',
  0xE5: 'a',
  0xE7: 'c',
  0xE8: 'e',
  0xE9: 'e',
  0xEA: 'e',
  0xEB: 'e',
  0xEC: 'i',
  0xED: 'i',
  0xEE: 'i',
  0xEF: 'i',
  0xF2: 'o',
  0xF3: 'o',
  0xF4: 'o',
  0xF5: 'o',
  0xF6: 'o',
  0xF9: 'u',
  0xFA: 'u',
  0xFB: 'u',
  0xFC: 'u',
};

// Text normalisation and the local search index. Offline, instant, and
// accent-insensitive so "santo antonio" finds "Santo Antônio".
// See docs/ui/UI_SPEC.md 7.3.
import 'package:pontual/ui/models/line_vm.dart';

/// Lowercase, strips diacritics and collapses whitespace.
String normalizeText(String input) {
  final StringBuffer out = StringBuffer();
  for (final int rune in input.toLowerCase().runes) {
    final String? replaced = _diacritics[rune];
    out.write(replaced ?? String.fromCharCode(rune));
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Latin-1 and Latin Extended letters that appear in pt-BR place names.
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
  0xF0: 'o',
  0xF1: 'n',
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

/// Rank buckets, lower is better. Exact short code beats a name prefix,
/// which beats a terminal prefix, which beats a plain contains match.
enum MatchRank {
  /// The query equals the badge code.
  exactCode(0),

  /// The name starts with the query.
  namePrefix(1),

  /// A terminal starts with the query.
  terminalPrefix(2),

  /// Any field contains the query.
  contains(3);

  /// Creates a rank with its numeric order.
  const MatchRank(this.order);

  /// Numeric order used for sorting.
  final int order;
}

/// One scored match.
class LineMatch {
  /// Creates a match for [line] with [rank].
  const LineMatch({required this.line, required this.rank});

  /// The matched line.
  final LineVM line;

  /// How well it matched.
  final MatchRank rank;
}

/// Builds the searchable haystacks of a line once.
class LineIndex {
  /// Creates an index entry for [line].
  LineIndex(this.line)
    : haystack = <String>[
        normalizeText(line.name),
        normalizeText(line.short ?? ''),
        ...line.terminals.map(normalizeText),
        ...line.areaTags.map(normalizeText),
      ],
      code = normalizeText(line.short ?? '');

  /// Indexed line.
  final LineVM line;

  /// Normalised fields to match against.
  final List<String> haystack;

  /// Normalised badge code.
  final String code;
}

/// Builds the index for a list of lines. Runs once per data change.
List<LineIndex> buildLineIndex(List<LineVM> lines) {
  return lines.map(LineIndex.new).toList();
}

/// Searches [index] for [rawQuery]. Empty queries return nothing so the
/// caller shows recent and suggestions instead.
List<LineMatch> searchLines(List<LineIndex> index, String rawQuery) {
  final String query = normalizeText(rawQuery);
  if (query.isEmpty) {
    return const <LineMatch>[];
  }
  final List<LineMatch> hits = <LineMatch>[];
  for (final LineIndex entry in index) {
    final MatchRank? rank = _rankFor(entry, query);
    if (rank != null) {
      hits.add(LineMatch(line: entry.line, rank: rank));
    }
  }
  hits.sort((LineMatch a, LineMatch b) {
    final int byRank = a.rank.order.compareTo(b.rank.order);
    if (byRank != 0) {
      return byRank;
    }
    return a.line.name.toLowerCase().compareTo(b.line.name.toLowerCase());
  });
  return hits;
}

MatchRank? _rankFor(LineIndex entry, String query) {
  if (entry.code.isNotEmpty && entry.code == query) {
    return MatchRank.exactCode;
  }
  final String name = entry.haystack[0];
  if (name.startsWith(query)) {
    return MatchRank.namePrefix;
  }
  for (int i = 1; i < entry.haystack.length; i++) {
    final String field = entry.haystack[i];
    if (field.startsWith(query)) {
      return MatchRank.terminalPrefix;
    }
  }
  for (final String field in entry.haystack) {
    if (field.contains(query)) {
      return MatchRank.contains;
    }
  }
  return null;
}

/// True when every whitespace token of [query] appears in the haystack.
bool matchesAllTokens(List<String> haystack, String query) {
  final List<String> tokens = query
      .split(' ')
      .where((String t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) {
    return false;
  }
  return tokens.every(
    (String token) => haystack.any((String field) => field.contains(token)),
  );
}

/// Highlight ranges of [query] inside [text], for the search result rows.
/// Empty when there is nothing to highlight.
List<int> highlightRanges(String text, String query) {
  final String needle = normalizeText(query);
  if (needle.isEmpty) {
    return const <int>[];
  }
  final int at = normalizeText(text).indexOf(needle);
  if (at < 0) {
    return const <int>[];
  }
  return <int>[at, at + needle.length];
}

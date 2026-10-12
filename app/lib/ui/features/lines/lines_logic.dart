// Pure helpers for the Linhas list: category grouping and sorting.
// No widgets here, so unit tests stay free of the render tree.
// See docs/ui/lines-redesign.md.
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/models/line_vm.dart';

/// One row of the flat Linhas list: a header or a line.
sealed class LinesListItem {
  /// Creates a list item.
  const LinesListItem();
}

/// Section header for one category.
class LinesHeaderItem extends LinesListItem {
  /// Creates a header for [category] with [count] lines.
  const LinesHeaderItem({required this.category, required this.count});

  /// Category of the section.
  final LineCategory category;

  /// Lines in the section.
  final int count;
}

/// One line row.
class LinesLineItem extends LinesListItem {
  /// Creates a line item for [line].
  const LinesLineItem(this.line);

  /// Line shown by the row.
  final LineVM line;
}

/// Numeric line number for sorting, null when the badge is not numeric.
int? lineNumberOf(LineVM line) {
  final String? short = line.short;
  if (short == null || short.isEmpty) {
    return null;
  }
  return int.tryParse(short);
}

/// Sorts lines by category order, then by numeric badge, then by name.
/// Live and favourite states never affect the order: color groups own it.
List<LineVM> sortedByCategory(List<LineVM> lines) {
  final List<LineVM> sorted = List<LineVM>.of(lines);
  sorted.sort((LineVM a, LineVM b) {
    final LineCategory ca = categoryFor(
      short: a.short ?? '',
      name: a.name,
      terminals: a.terminals,
      areaTags: a.areaTags,
    );
    final LineCategory cb = categoryFor(
      short: b.short ?? '',
      name: b.name,
      terminals: b.terminals,
      areaTags: b.areaTags,
    );
    final int byCategory = lineCategoryOrder(
      ca,
    ).compareTo(lineCategoryOrder(cb));
    if (byCategory != 0) {
      return byCategory;
    }
    final int? na = lineNumberOf(a);
    final int? nb = lineNumberOf(b);
    if (na != null && nb != null && na != nb) {
      return na.compareTo(nb);
    }
    if (na != null && nb == null) {
      return -1;
    }
    if (na == null && nb != null) {
      return 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// Groups [lines] into a flat header plus line sequence for the Todas filter.
/// Empty categories are dropped. Headers carry their line count.
List<LinesListItem> groupedLines(List<LineVM> lines) {
  final List<LineVM> sorted = sortedByCategory(lines);
  final List<LinesListItem> out = <LinesListItem>[];
  LineCategory? current;
  List<LineVM> bucket = <LineVM>[];
  void flush() {
    if (current != null && bucket.isNotEmpty) {
      out.add(LinesHeaderItem(category: current, count: bucket.length));
      for (final LineVM line in bucket) {
        out.add(LinesLineItem(line));
      }
      bucket = <LineVM>[];
    }
  }

  for (final LineVM line in sorted) {
    final LineCategory category = categoryFor(
      short: line.short ?? '',
      name: line.name,
      terminals: line.terminals,
      areaTags: line.areaTags,
    );
    if (current != category) {
      flush();
      current = category;
    }
    bucket.add(line);
  }
  flush();
  return out;
}

// Pure helpers for the Início screen: subtitle dedupe, section title,
// departure dedupe keys, shortcut state resolution, direction labels and
// the first departure of the next day. No widgets here, so the unit tests
// stay free of the render tree.
// See docs/ui/home-redesign.md.
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Minutes before departure that still count as leaving now.
const int leavingNowThresholdMin = 15;

/// Minutes below which a scheduled departure counts as imminent.
const int imminentThresholdMin = 10;

/// Visible states of a shortcut card. Every state has explicit copy;
/// none of them is an empty dash.
enum ShortcutCardState {
  /// Next departure further than the imminent threshold away.
  upcoming,

  /// Next departure under the imminent threshold away.
  imminent,

  /// A bus on the shortcut line is being shared right now.
  live,

  /// The timetable has no more departures today.
  noneToday,

  /// The line has no usable timetable at all.
  noData,
}

/// Splits [subtitle] on `·`, trims every part, drops empties and removes
/// duplicates preserving order.
List<String> dedupeSubtitleParts(String subtitle) {
  final List<String> out = <String>[];
  for (final String part in subtitle.split('·')) {
    final String trimmed = part.trim();
    if (trimmed.isEmpty || out.contains(trimmed)) {
      continue;
    }
    out.add(trimmed);
  }
  return out;
}

/// Joins subtitle parts with `·`, deduping across part boundaries so a
/// terminals text of `Litorâneo · Aviação` plus an origin of `Aviação`
/// renders once.
String joinSubtitle(List<String> parts) {
  final List<String> out = <String>[];
  for (final String part in parts) {
    for (final String sub in part.split('·')) {
      final String trimmed = sub.trim();
      if (trimmed.isEmpty || out.contains(trimmed)) {
        continue;
      }
      out.add(trimmed);
    }
  }
  return out.join(' · ');
}

/// Section title for the departures feed. `Saindo agora` only when the
/// soonest departure is within [leavingNowThresholdMin] minutes (a live
/// bus reports `at` near now, so it qualifies); otherwise the honest
/// default `Próximas saídas`. A null soonest also maps to the default.
String proximasSectionTitle(DateTime? soonestAt, DateTime now) {
  if (soonestAt != null &&
      soonestAt.difference(now).inSeconds <= leavingNowThresholdMin * 60) {
    return UiStrings.saindoAgora;
  }
  return UiStrings.nextDepartures;
}

/// Dedupe key of one timetable departure: line plus stop or direction
/// plus departure time.
String departureKey(String lineKey, String? originLabel, DateTime at) {
  return 'time|$lineKey|${originLabel ?? ''}|${at.toIso8601String()}';
}

/// Dedupe key of a live line entry. Live cards show no departure time,
/// so they dedupe on line plus origin only.
String liveKey(String lineKey, String? originLabel) {
  return 'live|$lineKey|${originLabel ?? ''}';
}

/// Drops every row whose [keyOf] is already in [shownKeys] (the content
/// the shortcut cards display), preserving order.
List<T> dropShownDepartures<T>(
  List<T> rows,
  Set<String> shownKeys,
  String Function(T row) keyOf,
) {
  return rows.where((T row) => !shownKeys.contains(keyOf(row))).toList();
}

/// Resolves the visible state of a shortcut card. Live wins over the
/// timetable; a missing next departure means no more today when the line
/// has any timetable rows, and no data otherwise.
ShortcutCardState resolveShortcutState({
  required bool isLive,
  required ArrivalVM? next,
  required DateTime? now,
  required bool hasTimetable,
}) {
  if (isLive) {
    return ShortcutCardState.live;
  }
  final ArrivalVM? upcoming = next;
  final DateTime? at = now;
  if (upcoming == null || at == null) {
    return hasTimetable
        ? ShortcutCardState.noneToday
        : ShortcutCardState.noData;
  }
  return upcoming.at.difference(at).inSeconds < imminentThresholdMin * 60
      ? ShortcutCardState.imminent
      : ShortcutCardState.upcoming;
}

/// Muted second line of a shortcut card, derived from existing data.
/// With a known origin and two terminals it reads `sentido <destino>`;
/// with a known origin alone it repeats the origin; without an origin
/// it falls back to the terminals text. Null when nothing is known.
String? directionLabel({
  required List<String> terminals,
  required String? originLabel,
}) {
  final String? origin = originLabel?.trim();
  if (origin != null && origin.isNotEmpty) {
    for (final String terminal in terminals) {
      final String trimmed = terminal.trim();
      if (trimmed.isNotEmpty && trimmed != origin) {
        return 'sentido $trimmed';
      }
    }
    return origin;
  }
  final List<String> known = terminals
      .map((String t) => t.trim())
      .where((String t) => t.isNotEmpty)
      .toList();
  if (known.isEmpty) {
    return null;
  }
  return known.join(' · ');
}

/// First departure time (`HH:mm`) for the day after [now], or null when
/// the timetable has none. Powers the `Amanhã 06:10` hint; derived
/// client-side from the bundled timetables, no model change.
String? firstDepartureTomorrow(
  StaticLine line,
  String? originLabel,
  DateTime now,
) {
  final DateTime tomorrow = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  final TimetableArrivalsSource source = TimetableArrivalsSource(
    line: line,
    now: tomorrow,
  );
  List<ArrivalVM> departures = source.departures(
    ArrivalQuery(lineKey: line.code, originLabel: originLabel, limit: 1),
  );
  if (departures.isEmpty && originLabel != null) {
    departures = source.departures(ArrivalQuery(lineKey: line.code, limit: 1));
  }
  if (departures.isEmpty) {
    return null;
  }
  return formatClock(departures.first.at);
}

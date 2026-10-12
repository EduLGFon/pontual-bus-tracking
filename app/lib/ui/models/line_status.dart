// Line row status: one status line that always exists. Pure and unit tested.
// Live wins, then timetable states. A departure at the current minute counts
// as now. See docs/ui/lines-redesign.md.
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/util/search_index.dart';

/// Visible states of a line row status line.
enum LineStatusKind {
  /// A bus is sharing on this line right now.
  live,

  /// Next departure is at the current minute.
  now,

  /// Next departure is under the imminent threshold.
  imminent,

  /// Next departure is further away.
  upcoming,

  /// Nothing left today; first departure of the next service day is known.
  tomorrow,

  /// Nothing left today and tomorrow is unknown.
  noneToday,

  /// The line has no usable timetable at all.
  noTimetable,
}

/// Minutes below which a scheduled departure counts as imminent.
const int lineImminentThresholdMin = 10;

/// Status of one line row.
class LineStatus {
  /// Creates a status.
  const LineStatus({required this.kind, this.time, this.minutes});

  /// Creates the live status.
  const LineStatus.live() : kind = LineStatusKind.live, time = null, minutes = null;

  /// Creates the no-timetable status.
  const LineStatus.noTimetable()
    : kind = LineStatusKind.noTimetable,
      time = null,
      minutes = null;

  /// Creates the none-today status (tomorrow unknown).
  const LineStatus.noneToday()
    : kind = LineStatusKind.noneToday,
      time = null,
      minutes = null;

  /// Kind of the status.
  final LineStatusKind kind;

  /// HH:mm of the departure, for now, imminent, upcoming and tomorrow.
  final String? time;

  /// Minutes until the departure, for imminent and upcoming.
  final int? minutes;
}

/// Resolves the visible status of a line row. Live wins over the timetable;
/// a missing next departure means no more today when the line has any
/// timetable rows, and no data otherwise. [next] is the shared
/// [NextDeparture] resolution for today plus tomorrow.
LineStatus resolveLineStatus({
  required bool isLive,
  required bool hasTimetable,
  required NextDeparture? next,
  required int nowMinutes,
}) {
  if (isLive) {
    return const LineStatus.live();
  }
  if (!hasTimetable) {
    return const LineStatus.noTimetable();
  }
  if (next == null) {
    return const LineStatus.noneToday();
  }
  if (next.isTomorrow) {
    return LineStatus(kind: LineStatusKind.tomorrow, time: next.time);
  }
  final int minutes = minutesUntil(next.time, nowMinutes);
  if (minutes <= 0) {
    return LineStatus(kind: LineStatusKind.now, time: next.time);
  }
  if (minutes < lineImminentThresholdMin) {
    return LineStatus(
      kind: LineStatusKind.imminent,
      time: next.time,
      minutes: minutes,
    );
  }
  return LineStatus(
    kind: LineStatusKind.upcoming,
    time: next.time,
    minutes: minutes,
  );
}

/// True when the terminals add information beyond the title.
/// Normalizes accents and case before comparing; every terminal already
/// contained in the title hides the subtitle.
bool shouldShowTerminals(String name, List<String> terminals) {
  final String title = normalizeText(name);
  if (title.isEmpty) {
    return terminals.isNotEmpty;
  }
  for (final String terminal in terminals) {
    final String norm = normalizeText(terminal);
    if (norm.isEmpty) {
      continue;
    }
    if (!title.contains(norm)) {
      return true;
    }
  }
  return false;
}

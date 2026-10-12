// Pure schedule helpers. No Flutter imports. Day-type default follows the
// São Mateus calendar: Saturday maps to saturday, Sunday to
// sunday_holiday; public holidays are not auto-detected in alpha and the
// user switches manually. Times are HH:mm on a fixed UTC-3 offset.
// See PLAN.md S05.
library;

/// Day types used by timetables.
enum DayType {
  /// Monday to Friday.
  weekday,

  /// Saturday.
  saturday,

  /// Sunday and holidays.
  sundayHoliday,
}

/// Day type for a São Mateus local date.
DayType dayTypeFor(DateTime local) {
  if (local.weekday == DateTime.saturday) {
    return DayType.saturday;
  }
  if (local.weekday == DateTime.sunday) {
    return DayType.sundayHoliday;
  }
  return DayType.weekday;
}

/// São Mateus wall time for an instant. Fixed UTC-3, no DST in alpha.
DateTime saoMateusTime(DateTime instant) {
  return instant.toUtc().add(const Duration(hours: -3));
}

/// Minutes since midnight for an HH:mm time.
int minutesOf(String hhmm) {
  final List<String> parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Minutes since midnight of a São Mateus wall-clock instant.
int nowMinutesOf(DateTime local) {
  return local.hour * 60 + local.minute;
}

/// True when [a] and [b] share the same calendar minute.
bool isSameMinute(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;
}

/// True when the minute of [at] is before the minute of [now].
/// A departure at the current minute counts as now, not past.
bool isPastMinute(DateTime at, DateTime now) {
  final DateTime a = DateTime.utc(
    at.year,
    at.month,
    at.day,
    at.hour,
    at.minute,
  );
  final DateTime b = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  );
  return a.isBefore(b);
}

/// First departure at or after [nowMinutes], or null when none remains.
/// A departure at the current minute counts as now: after that minute it
/// is past and never shown as next. Never persist the result.
String? nextDeparture(List<String> times, int nowMinutes) {
  String? best;
  int bestMinutes = 0;
  for (final String t in times) {
    final int minutes = minutesOf(t);
    if (minutes < nowMinutes) {
      continue;
    }
    if (best == null || minutes < bestMinutes) {
      best = t;
      bestMinutes = minutes;
    }
  }
  return best;
}

/// Minutes from [nowMinutes] until an HH:mm departure.
int minutesUntil(String hhmm, int nowMinutes) {
  return minutesOf(hhmm) - nowMinutes;
}

/// Next departure with its day. Today wins at or after [nowMinutes];
/// otherwise the earliest time of [tomorrowTimes] wins. Null when both
/// lists are empty. Inputs may be unsorted. Never persist the result.
NextDeparture? resolveNextDeparture({
  required List<String> todayTimes,
  required List<String> tomorrowTimes,
  required int nowMinutes,
}) {
  final String? today = nextDeparture(todayTimes, nowMinutes);
  if (today != null) {
    return NextDeparture(time: today, isTomorrow: false);
  }
  final String? tomorrow = earliestTime(tomorrowTimes);
  if (tomorrow != null) {
    return NextDeparture(time: tomorrow, isTomorrow: true);
  }
  return null;
}

/// Earliest HH:mm in [times], or null when empty. Inputs may be unsorted.
String? earliestTime(List<String> times) {
  String? best;
  int bestMinutes = 0;
  for (final String t in times) {
    final int minutes = minutesOf(t);
    if (best == null || minutes < bestMinutes) {
      best = t;
      bestMinutes = minutes;
    }
  }
  return best;
}

/// Next departure with its day.
class NextDeparture {
  /// Creates the resolution.
  const NextDeparture({required this.time, required this.isTomorrow});

  /// HH:mm of the departure.
  final String time;

  /// True when the time belongs to the next service day.
  final bool isTomorrow;
}

/// Groups times by hour preserving order, e.g. {"05": ["05:30"]}.
Map<String, List<String>> groupByHour(List<String> times) {
  final Map<String, List<String>> groups = <String, List<String>>{};
  for (final String t in times) {
    final String hour = t.split(':').first;
    groups.putIfAbsent(hour, () => <String>[]).add(t);
  }
  return groups;
}

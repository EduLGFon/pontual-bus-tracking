// Pure timetable shaping: day-type keys, origins, HH:mm parsing and the
// scheduled arrivals the sheets draw. No Flutter imports, no clock of its
// own. Kept apart from the widget so the rules are unit-testable on their
// own. See docs/ui/UI_SPEC.md 7.6.
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Height of one hour row of the timetable rail, in dp.
const double railRowDp = 56;

/// Day types shown by the selector, in order.
const List<DayType> dayTypes = <DayType>[
  DayType.weekday,
  DayType.saturday,
  DayType.sundayHoliday,
];

/// Day-type key used by the bundled static data.
String dayTypeKeyOf(DayType day) {
  return switch (day) {
    DayType.weekday => 'weekday',
    DayType.saturday => 'saturday',
    DayType.sundayHoliday => 'sunday_holiday',
  };
}

/// Day type for a static data key, null when the key is unknown.
DayType? dayForKey(String key) {
  for (final DayType day in dayTypes) {
    if (dayTypeKeyOf(day) == key) {
      return day;
    }
  }
  return null;
}

/// pt-BR label of a day type, taken from the strings file.
String dayTypeLabelOf(DayType day) {
  return switch (day) {
    DayType.weekday => UiStrings.dayWeekday,
    DayType.saturday => UiStrings.daySaturday,
    DayType.sundayHoliday => UiStrings.daySunday,
  };
}

/// Origins with schedules for [day], sorted. Empty when the data has none,
/// which hides the origin selector per the spec.
List<String> timetableOriginsOf(StaticLine line, DayType day) {
  final Set<String> origins = <String>{};
  for (final Map<String, dynamic> s in line.schedules) {
    if ((s['day_type'] as String? ?? '') != dayTypeKeyOf(day)) {
      continue;
    }
    final Object? origin = s['origin'];
    if (origin is String && origin.isNotEmpty) {
      origins.add(origin);
    }
  }
  return origins.toList()..sort();
}

/// Times for [day], optionally limited to one [origin]. Sorted and
/// deduplicated so two origins cannot show the same minute twice. Unknown
/// day types and shapes return an empty list instead of throwing.
List<String> timetableTimesOf(StaticLine line, DayType day, String? origin) {
  final Set<String> times = <String>{};
  for (final Map<String, dynamic> s in line.schedules) {
    if ((s['day_type'] as String? ?? '') != dayTypeKeyOf(day)) {
      continue;
    }
    if (origin != null &&
        origin.isNotEmpty &&
        (s['origin'] as String? ?? '') != origin) {
      continue;
    }
    final List<dynamic> raw = s['times'] as List<dynamic>? ?? <dynamic>[];
    times.addAll(raw.whereType<String>());
  }
  return times.toList()..sort();
}

/// True when [line] has at least one usable timetable time.
/// Derived from data, never hardcoded. Lines without a timetable are
/// still valid: riders can share live position on them.
bool hasTimetable(StaticLine line) {
  for (final Map<String, dynamic> s in line.schedules) {
    final List<dynamic> raw = s['times'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic t in raw) {
      if (t is String && t.isNotEmpty) {
        return true;
      }
    }
  }
  return false;
}

/// Builds scheduled arrivals from HH:mm strings on the date of [now].
/// Certainty is always [Certainty.scheduled]: a timetable is a promise
/// about time, never about position.
List<ArrivalVM> arrivalsOf(
  String lineKey,
  List<String> times,
  DateTime now, {
  int limit = 0,
  String? originLabel,
}) {
  final List<ArrivalVM> out = <ArrivalVM>[];
  for (final String t in times) {
    final int? minutes = parseMinutesOf(t);
    if (minutes == null) {
      continue;
    }
    out.add(
      ArrivalVM(
        lineKey: lineKey,
        at: DateTime.utc(
          now.year,
          now.month,
          now.day,
          minutes ~/ 60,
          minutes % 60,
        ),
        certainty: Certainty.scheduled,
        asOf: now,
        originLabel: originLabel,
      ),
    );
  }
  if (limit <= 0) {
    return out;
  }
  return out.take(limit).toList();
}

/// Minutes since midnight of a well-formed HH:mm string, null otherwise.
int? parseMinutesOf(String hhmm) {
  final List<String> parts = hhmm.split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return hour * 60 + minute;
}

/// `dd/MM/yyyy` of the São Mateus date of [instant].
String formatDateLabel(DateTime instant) {
  final DateTime local = saoMateusTime(instant);
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// Formats a component with two digits.
String _two(int value) => value.toString().padLeft(2, '0');

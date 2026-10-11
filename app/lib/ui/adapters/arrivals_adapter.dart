// Arrivals seam. The UI asks for arrivals and does not care where they come
// from. Today the only source is the static timetable; live and predicted
// sources plug in later without touching any screen.
// See docs/ui/UI_SPEC.md 6.3.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';

/// What the UI asks for.
class ArrivalQuery {
  /// Creates a query.
  const ArrivalQuery({required this.lineKey, this.originLabel, this.limit = 4});

  /// Stable line key.
  final String lineKey;

  /// Origin terminal, when the line has more than one.
  final String? originLabel;

  /// How many arrivals to return.
  final int limit;
}

/// The seam every arrival source implements.
abstract interface class ArrivalsSource {
  /// Watches arrivals for [query].
  Stream<List<ArrivalVM>> watch(ArrivalQuery query);
}

/// Timetable arrivals. Certainty is always [Certainty.scheduled].
class TimetableArrivalsSource implements ArrivalsSource {
  /// Creates the source over [line] and [now].
  const TimetableArrivalsSource({required this.line, required this.now});

  /// Line with its schedules.
  final StaticLine line;

  /// Current instant, converted to São Mateus wall clock inside.
  final DateTime now;

  @override
  Stream<List<ArrivalVM>> watch(ArrivalQuery query) {
    return Stream<List<ArrivalVM>>.fromIterable(<List<ArrivalVM>>[
      departures(query),
    ]);
  }

  /// Next departures for [query], in order.
  List<ArrivalVM> departures(ArrivalQuery query) {
    final List<String> times = _timesFor(query.originLabel);
    final List<ArrivalVM> all = <ArrivalVM>[];
    for (final String t in times) {
      final DateTime at = _atOf(t);
      all.add(
        ArrivalVM(
          lineKey: line.code,
          at: at,
          certainty: Certainty.scheduled,
          asOf: now,
          originLabel: query.originLabel,
        ),
      );
    }
    all.sort((ArrivalVM a, ArrivalVM b) => a.at.compareTo(b.at));
    if (query.limit <= 0) {
      return all;
    }
    return all.take(query.limit).toList();
  }

  /// All origins present in the data for a day type.
  List<String> originsFor(String dayType) {
    final Set<String> origins = <String>{};
    for (final Map<String, dynamic> s in line.schedules) {
      final String type = s['day_type'] as String? ?? '';
      if (type != dayType) {
        continue;
      }
      final Object? origin = s['origin'];
      if (origin is String && origin.isNotEmpty) {
        origins.add(origin);
      }
    }
    return origins.toList()..sort();
  }

  /// Times for one origin, sorted. Empty when the line has no schedules.
  List<String> timesFor(String dayType, String? origin) {
    for (final Map<String, dynamic> s in line.schedules) {
      final String type = s['day_type'] as String? ?? '';
      final String from = s['origin'] as String? ?? '';
      if (type == dayType && from == origin) {
        final List<dynamic> times = s['times'] as List<dynamic>? ?? <dynamic>[];
        return times.whereType<String>().toList()..sort();
      }
    }
    return const <String>[];
  }

  List<String> _timesFor(String? origin) {
    if (origin == null) {
      final Set<String> merged = <String>{};
      for (final Map<String, dynamic> s in line.schedules) {
        final List<dynamic> times = s['times'] as List<dynamic>? ?? <dynamic>[];
        merged.addAll(times.whereType<String>());
      }
      return merged.toList()..sort();
    }
    return timesFor('', origin);
  }

  DateTime _atOf(String hhmm) {
    final List<String> parts = hhmm.split(':');
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

/// Provides the arrivals source for one line, refreshed with the clock.
final arrivalsSourceProvider = Provider.family<ArrivalsSource, StaticLine>((
  Ref ref,
  StaticLine line,
) {
  final DateTime now = ref.watch(currentNowProvider);
  return TimetableArrivalsSource(line: line, now: now);
});

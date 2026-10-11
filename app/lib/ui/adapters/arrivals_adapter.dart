// Arrivals seam. The UI asks for arrivals and does not care where they come
// from. Today the only source is the static timetable; live and predicted
// sources plug in later without touching any screen.
// See docs/ui/UI_SPEC.md 6.3.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

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

  /// Next departures for [query], in order. Only the day type of [now]
  /// is considered: a Sunday query over weekday-only data returns empty
  /// instead of surfacing a weekday time on the wrong day. D-U26.
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
    final String dayKey = _dayTypeKey(dayTypeFor(now));
    if (origin == null) {
      final Set<String> merged = <String>{};
      for (final Map<String, dynamic> s in line.schedules) {
        final String type = s['day_type'] as String? ?? '';
        if (type != dayKey) {
          continue;
        }
        final List<dynamic> times = s['times'] as List<dynamic>? ?? <dynamic>[];
        merged.addAll(times.whereType<String>());
      }
      return merged.toList()..sort();
    }
    return timesFor(dayKey, origin);
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

/// Static-data key of a day type. [now] is already the São Mateus wall
/// clock from [currentNowProvider], so no extra conversion applies here.
String _dayTypeKey(DayType type) {
  return switch (type) {
    DayType.weekday => 'weekday',
    DayType.saturday => 'saturday',
    DayType.sundayHoliday => 'sunday_holiday',
  };
}

/// Provides the arrivals source for one line, refreshed with the clock.
final arrivalsSourceProvider = Provider.family<ArrivalsSource, StaticLine>((
  Ref ref,
  StaticLine line,
) {
  final DateTime now = ref.watch(currentNowProvider);
  return TimetableArrivalsSource(line: line, now: now);
});

/// Live-aware source. Overlays live and predicted arrivals when the
/// backend provides ETA; until then it answers the timetable base with
/// no layout change. Flagged by `Features.eta`.
class LiveAwareArrivalsSource implements ArrivalsSource {
  /// Creates the source over the timetable [base].
  const LiveAwareArrivalsSource({required this.base});

  /// Timetable source underneath.
  final ArrivalsSource base;

  @override
  Stream<List<ArrivalVM>> watch(ArrivalQuery query) => base.watch(query);
}

/// Live hero for a line screen: the freshest live vehicle wins as
/// "now", else the freshest labeled prediction. Null when nothing is
/// live or predicted. Lets the Agora hero lead with realtime while the
/// timetable stays below. Pure, D30.
ArrivalVM? liveHeroOf(String lineKey, List<VehicleVM> vehicles, DateTime now) {
  VehicleVM? live;
  for (final VehicleVM v in vehicles) {
    if (v.certainty == Certainty.live &&
        (live == null || v.ageSeconds < live.ageSeconds)) {
      live = v;
    }
  }
  if (live != null) {
    return ArrivalVM(
      lineKey: lineKey,
      at: now,
      certainty: Certainty.live,
      asOf: now.subtract(Duration(seconds: live.ageSeconds)),
    );
  }
  VehicleVM? predicted;
  for (final VehicleVM v in vehicles) {
    if (v.certainty == Certainty.predicted &&
        (predicted == null || v.ageSeconds < predicted.ageSeconds)) {
      predicted = v;
    }
  }
  if (predicted != null) {
    return ArrivalVM(
      lineKey: lineKey,
      at: now,
      certainty: Certainty.predicted,
      asOf: now.subtract(Duration(seconds: predicted.ageSeconds)),
    );
  }
  return null;
}

/// Merges sources with live winning over predicted over scheduled.
/// Flagged by `Features.eta`; today it holds one source.
class CompositeArrivalsSource implements ArrivalsSource {
  /// Creates the merge over [sources], highest priority first.
  const CompositeArrivalsSource({required this.sources});

  /// Sources in priority order.
  final List<ArrivalsSource> sources;

  @override
  Stream<List<ArrivalVM>> watch(ArrivalQuery query) {
    if (sources.isEmpty) {
      return Stream<List<ArrivalVM>>.value(const <ArrivalVM>[]);
    }
    return sources.first.watch(query);
  }

  /// Picks the winning arrival per line key by certainty rank (lower wins:
  /// live over predicted over scheduled; stale never wins anything).
  static List<ArrivalVM> mergeByRank(List<ArrivalVM> arrivals) {
    final Map<String, ArrivalVM> best = <String, ArrivalVM>{};
    for (final ArrivalVM a in arrivals) {
      final ArrivalVM? current = best[a.lineKey];
      if (current == null ||
          certaintyRank(a.certainty) < certaintyRank(current.certainty)) {
        best[a.lineKey] = a;
      }
    }
    return best.values.toList();
  }
}

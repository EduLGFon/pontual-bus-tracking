// Line adapter: maps the static data repository and the live-lines
// endpoint onto LineVM. Read-only: nothing here changes how data is loaded.
// See docs/ui/UI_SPEC.md 6.1 (UI may read data only through adapters).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/util/search_index.dart';

/// Converts a static line into its view-model.
LineVM lineVmOf(StaticLine line, {int liveCount = 0}) {
  return LineVM(
    key: line.code,
    name: line.name,
    short: line.short,
    terminals: line.terminals,
    areaTags: line.areaTags,
    isLive: liveCount > 0,
    liveVehicleCount: liveCount,
    supportsSharing: line.pilot,
  );
}

/// Lines with their live counts merged, sorted live first then by name.
final Provider<List<LineVM>> linesVmProvider = Provider<List<LineVM>>((
  Ref ref,
) {
  final AsyncValue<List<StaticLine>> lines = ref.watch(linesProvider);
  final Map<int, int> counts = _liveCounts(ref);
  return lines.maybeWhen(
    data: (List<StaticLine> all) {
      final List<LineVM> vms = all
          .where((StaticLine l) => l.isActive)
          .map((StaticLine l) => lineVmOf(l, liveCount: counts[l.id] ?? 0))
          .toList();
      vms.sort((LineVM a, LineVM b) {
        if (a.isLive != b.isLive) {
          return a.isLive ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return vms;
    },
    orElse: () => const <LineVM>[],
  );
});

/// Live counts by line id, from the live-lines endpoint.
Map<int, int> _liveCounts(Ref ref) {
  final Map<int, int> counts = <int, int>{};
  ref.watch(liveProvider).whenData((LiveLines live) {
    for (final List<int> row in live.rows) {
      counts[row[0]] = row[1];
    }
  });
  return counts;
}

/// The search index for the current lines. Built once per data change.
final Provider<List<LineIndex>> lineIndexProvider = Provider<List<LineIndex>>((
  Ref ref,
) {
  return buildLineIndex(ref.watch(linesVmProvider));
});

/// Looks a line up by its stable key.
final lineByKeyProvider = Provider.family<LineVM?, String>((
  Ref ref,
  String key,
) {
  for (final LineVM line in ref.watch(linesVmProvider)) {
    if (line.key == key) {
      return line;
    }
  }
  return null;
});

/// Live vehicle count for one line key.
int liveCountOfKey(List<LineVM> lines, String key) {
  for (final LineVM line in lines) {
    if (line.key == key) {
      return line.liveVehicleCount;
    }
  }
  return 0;
}

/// Static line id for a line key, null when unknown. The live stream is
/// keyed by numeric id at the data layer.
int? lineIdOfKey(List<StaticLine> lines, String key) {
  for (final StaticLine line in lines) {
    if (line.code == key) {
      return line.id;
    }
  }
  return null;
}

/// Status of one line key for the row status line. Watches the clock, so
/// only the status text rebuilds on tick, not the list order. Shared by
/// Linhas, Início live rows and Busca browse rows: one source, no second
/// implementation of the same rule.
final lineStatusProvider = Provider.family<LineStatus, String>((
  Ref ref,
  String key,
) {
  LineVM? vm;
  for (final LineVM line in ref.watch(linesVmProvider)) {
    if (line.key == key) {
      vm = line;
      break;
    }
  }
  if (vm == null) {
    return const LineStatus.noTimetable();
  }
  final List<StaticLine> statics =
      ref.watch(linesProvider).asData?.value ?? const <StaticLine>[];
  StaticLine? found;
  for (final StaticLine s in statics) {
    if (s.code == key) {
      found = s;
      break;
    }
  }
  final bool timed = found != null && hasTimetable(found);
  final DateTime now = ref.watch(currentNowProvider);
  final int nowMinutes = nowMinutesOf(now);
  NextDeparture? next;
  if (timed && found != null) {
    final List<String> today = timetableTimesOf(found, dayTypeFor(now), null);
    final DayType tomorrowType = dayTypeFor(now.add(const Duration(days: 1)));
    final List<String> tomorrow = timetableTimesOf(found, tomorrowType, null);
    next = resolveNextDeparture(
      todayTimes: today,
      tomorrowTimes: tomorrow,
      nowMinutes: nowMinutes,
    );
  }
  return resolveLineStatus(
    isLive: vm.isLive,
    hasTimetable: timed,
    next: next,
    nowMinutes: nowMinutes,
  );
});

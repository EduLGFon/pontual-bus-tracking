// Unit tests for the pure Início helpers. No widgets, no prefs, no
// network: fixed wall-clock instants and static line fixtures.
// See docs/ui/home-redesign.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/features/home/home_logic.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Reference instant: Wednesday 10:00 São Mateus wall clock held as UTC.
final DateTime now = DateTime.utc(2026, 10, 14, 10, 0);

ArrivalVM scheduledAt(DateTime at, {String? origin}) {
  return ArrivalVM(
    lineKey: '60-test',
    at: at,
    certainty: Certainty.scheduled,
    asOf: now,
    originLabel: origin,
  );
}

StaticLine testLine({
  required List<Map<String, dynamic>> schedules,
  List<String> terminals = const <String>['Litorâneo', 'Aviação'],
}) {
  return StaticLine(
    id: 60,
    code: '60-test',
    short: '60',
    name: 'Litorâneo / Aviação',
    pilot: true,
    schedules: schedules,
    terminals: terminals,
  );
}

Map<String, dynamic> dayRow(String origin, List<String> times) {
  return <String, dynamic>{
    'day_type': 'weekday',
    'origin': origin,
    'times': times,
  };
}

void main() {
  test('subtitle dedupe collapses a repeated origin', () {
    expect(
      joinSubtitle(<String>['Litorâneo · Aviação', 'Aviação']),
      'Litorâneo · Aviação',
    );
  });

  test('subtitle dedupe drops empties and keeps order', () {
    expect(joinSubtitle(<String>['', '  ', 'B', 'A', 'B']), 'B · A');
    expect(joinSubtitle(<String>['', '']), isEmpty);
  });

  test('section title switches at the 15 minute boundary', () {
    expect(proximasSectionTitle(null, now), UiStrings.nextDepartures);
    expect(
      proximasSectionTitle(now.add(const Duration(minutes: 63)), now),
      UiStrings.nextDepartures,
    );
    expect(
      proximasSectionTitle(now.add(const Duration(minutes: 15)), now),
      UiStrings.saindoAgora,
    );
    expect(
      proximasSectionTitle(
        now.add(const Duration(minutes: 15, seconds: 1)),
        now,
      ),
      UiStrings.nextDepartures,
    );
    expect(
      proximasSectionTitle(now.add(const Duration(minutes: 6)), now),
      UiStrings.saindoAgora,
    );
  });

  test('departure dedupe drops shown rows and keeps order', () {
    final DateTime first = now.add(const Duration(minutes: 20));
    final DateTime second = now.add(const Duration(minutes: 40));
    final List<String> rows = <String>[
      departureKey('a', null, first),
      departureKey('b', 'Aviação', second),
    ];
    final List<String> fresh = dropShownDepartures(rows, <String>{
      departureKey('a', null, first),
    }, (String row) => row);
    expect(fresh, <String>[departureKey('b', 'Aviação', second)]);
    expect(liveKey('a', null) == departureKey('a', null, first), isFalse);
  });

  test('shortcut state resolves live first', () {
    expect(
      resolveShortcutState(
        isLive: true,
        next: null,
        now: now,
        hasTimetable: true,
      ),
      ShortcutCardState.live,
    );
  });

  test('shortcut state splits imminent from upcoming at 10 minutes', () {
    expect(
      resolveShortcutState(
        isLive: false,
        next: scheduledAt(now.add(const Duration(minutes: 6))),
        now: now,
        hasTimetable: true,
      ),
      ShortcutCardState.imminent,
    );
    expect(
      resolveShortcutState(
        isLive: false,
        next: scheduledAt(now.add(const Duration(minutes: 63))),
        now: now,
        hasTimetable: true,
      ),
      ShortcutCardState.upcoming,
    );
  });

  test('shortcut state without a next departure is explicit', () {
    expect(
      resolveShortcutState(
        isLive: false,
        next: null,
        now: now,
        hasTimetable: true,
      ),
      ShortcutCardState.noneToday,
    );
    expect(
      resolveShortcutState(
        isLive: false,
        next: null,
        now: null,
        hasTimetable: false,
      ),
      ShortcutCardState.noData,
    );
  });

  test('direction label prefers the destination terminal', () {
    expect(
      directionLabel(
        terminals: const <String>['Litorâneo', 'Aviação'],
        originLabel: 'Aviação',
      ),
      'sentido Litorâneo',
    );
    expect(
      directionLabel(terminals: const <String>[], originLabel: 'Aviação'),
      'Aviação',
    );
    expect(
      directionLabel(
        terminals: const <String>['Litorâneo', 'Aviação'],
        originLabel: null,
      ),
      'Litorâneo · Aviação',
    );
    expect(
      directionLabel(terminals: const <String>[], originLabel: null),
      isNull,
    );
  });

  test('tomorrow lookup returns the first departure of the next day', () {
    final StaticLine line = testLine(
      schedules: <Map<String, dynamic>>[
        dayRow('Litorâneo', <String>['05:40', '10:20']),
        dayRow('Aviação', <String>['06:00', '11:00']),
      ],
    );
    // Thursday is a weekday in the fixture, so the first Litorâneo time.
    expect(firstDepartureTomorrow(line, 'Litorâneo', now), '05:40');
    // Unknown origin falls back to the merged timetable.
    expect(firstDepartureTomorrow(line, 'Xyz', now), '05:40');
    expect(
      firstDepartureTomorrow(
        testLine(schedules: const <Map<String, dynamic>>[]),
        null,
        now,
      ),
      isNull,
    );
  });
}

// Tests for the line row status resolver and the subtitle dedupe.
// No widgets: fixed wall-clock minutes and timetable fixtures.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/models/line_status.dart';

void main() {
  test('live wins over every timetable state', () {
    expect(
      resolveLineStatus(
        isLive: true,
        hasTimetable: false,
        next: null,
        nowMinutes: 600,
      ).kind,
      LineStatusKind.live,
    );
  });

  test('missing timetable is an honest state', () {
    expect(
      resolveLineStatus(
        isLive: false,
        hasTimetable: false,
        next: null,
        nowMinutes: 600,
      ).kind,
      LineStatusKind.noTimetable,
    );
  });

  test('current minute is now, under ten is imminent', () {
    expect(
      resolveLineStatus(
        isLive: false,
        hasTimetable: true,
        next: const NextDeparture(time: '10:00', isTomorrow: false),
        nowMinutes: 600,
      ).kind,
      LineStatusKind.now,
    );
    final LineStatus imminent = resolveLineStatus(
      isLive: false,
      hasTimetable: true,
      next: const NextDeparture(time: '10:06', isTomorrow: false),
      nowMinutes: 600,
    );
    expect(imminent.kind, LineStatusKind.imminent);
    expect(imminent.minutes, 6);
  });

  test('further departures stay upcoming with minutes', () {
    final LineStatus status = resolveLineStatus(
      isLive: false,
      hasTimetable: true,
      next: const NextDeparture(time: '11:03', isTomorrow: false),
      nowMinutes: 600,
    );
    expect(status.kind, LineStatusKind.upcoming);
    expect(status.minutes, 63);
  });

  test('tomorrow and none-today states are explicit', () {
    expect(
      resolveLineStatus(
        isLive: false,
        hasTimetable: true,
        next: const NextDeparture(time: '05:40', isTomorrow: true),
        nowMinutes: 1400,
      ).kind,
      LineStatusKind.tomorrow,
    );
    expect(
      resolveLineStatus(
        isLive: false,
        hasTimetable: true,
        next: null,
        nowMinutes: 1400,
      ).kind,
      LineStatusKind.noneToday,
    );
  });

  test('subtitle hides when every terminal is already in the title', () {
    expect(
      shouldShowTerminals('Centro / IFES / UFES', const <String>[
        'Centro',
        'IFES / UFES',
      ]),
      isFalse,
    );
    expect(
      shouldShowTerminals('Guriri via Beira Mar', const <String>[
        'Guriri',
        'Beira Mar',
      ]),
      isFalse,
    );
    expect(
      shouldShowTerminals('Bosque', const <String>['Bosque']),
      isFalse,
    );
    expect(
      shouldShowTerminals('Linha especial', const <String>['Centro']),
      isTrue,
    );
  });
}

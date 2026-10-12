// T25 tests: schedule logic for all day types plus the timetable tab.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';

const StaticLine demo = StaticLine(
  id: 60,
  code: 'demo',
  short: '60',
  name: 'Demo',
  pilot: true,
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'A',
      'times': <String>['05:30', '14:35'],
    },
    <String, dynamic>{
      'day_type': 'saturday',
      'origin': 'A',
      'times': <String>['06:00'],
    },
    <String, dynamic>{
      'day_type': 'sunday_holiday',
      'origin': 'A',
      'times': <String>['07:00'],
    },
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'B',
      'times': <String>['06:00'],
    },
  ],
);

void main() {
  test('day type follows the local date', () {
    // 2026-10-03 is a Saturday; 2026-10-04 a Sunday; 2026-10-05 a Monday.
    expect(dayTypeFor(DateTime(2026, 10, 3)), DayType.saturday);
    expect(dayTypeFor(DateTime(2026, 10, 4)), DayType.sundayHoliday);
    expect(dayTypeFor(DateTime(2026, 10, 5)), DayType.weekday);
  });

  test('next departure skips past times', () {
    expect(nextDeparture(<String>['05:30', '14:35'], 14 * 60), '14:35');
    expect(nextDeparture(<String>['05:30'], 6 * 60), isNull);
    expect(minutesUntil('14:35', 14 * 60 + 23), 12);
  });

  test('departure at the current minute counts as now', () {
    expect(nextDeparture(<String>['10:00', '11:00'], 10 * 60), '10:00');
    expect(nextDeparture(<String>['10:00'], 10 * 60 + 1), isNull);
    expect(
      isPastMinute(
        DateTime.utc(2026, 10, 14, 10, 0),
        DateTime.utc(2026, 10, 14, 10, 0, 30),
      ),
      isFalse,
    );
    expect(
      isPastMinute(
        DateTime.utc(2026, 10, 14, 10, 0),
        DateTime.utc(2026, 10, 14, 10, 1),
      ),
      isTrue,
    );
    expect(
      isSameMinute(
        DateTime.utc(2026, 10, 14, 10, 0, 5),
        DateTime.utc(2026, 10, 14, 10, 0, 55),
      ),
      isTrue,
    );
  });

  test('resolve rolls to tomorrow when nothing remains today', () {
    final NextDeparture? rolled = resolveNextDeparture(
      todayTimes: const <String>['05:40', '06:20'],
      tomorrowTimes: const <String>['05:40', '07:00'],
      nowMinutes: 23 * 60 + 10,
    );
    expect(rolled?.time, '05:40');
    expect(rolled?.isTomorrow, isTrue);
    expect(
      resolveNextDeparture(
        todayTimes: const <String>['05:40'],
        tomorrowTimes: const <String>[],
        nowMinutes: 23 * 60,
      ),
      isNull,
    );
    expect(
      resolveNextDeparture(
        todayTimes: const <String>['10:00', '09:00'],
        tomorrowTimes: const <String>[],
        nowMinutes: 8 * 60,
      )?.time,
      '09:00',
    );
  });

  test('friday night rolls to saturday type and saturday to sunday', () {
    // 2026-10-16 is a Friday, 2026-10-17 a Saturday.
    final DateTime friday = DateTime.utc(2026, 10, 16, 23, 50);
    final DateTime saturday = friday.add(const Duration(days: 1));
    expect(dayTypeFor(friday), DayType.weekday);
    expect(dayTypeFor(saturday), DayType.saturday);
    final DateTime saturdayNight = DateTime.utc(2026, 10, 17, 23, 50);
    expect(
      dayTypeFor(saturdayNight.add(const Duration(days: 1))),
      DayType.sundayHoliday,
    );
  });

  test('times group by hour', () {
    expect(
      groupByHour(<String>['05:30', '05:45', '06:10']),
      <String, List<String>>{
        '05': <String>['05:30', '05:45'],
        '06': <String>['06:10'],
      },
    );
  });
}

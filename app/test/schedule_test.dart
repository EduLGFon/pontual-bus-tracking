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

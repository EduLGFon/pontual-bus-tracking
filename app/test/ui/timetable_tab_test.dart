// Tests of the Horários tab: the day-type segments, the origin chips, the
// next departure hero, the hour rail and the empty state. Fixed São Mateus
// clock so every assertion is deterministic.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/features/timetable/timetable_tab.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Line with one origin and a weekday timetable.
const StaticLine oneOrigin = StaticLine(
  id: 1,
  code: 'one',
  short: '1',
  name: 'Um / Aroeira',
  pilot: true,
  terminals: <String>['Aroeira'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Aroeira',
      'times': <String>['05:30', '06:10', '14:35', '14:55', '19:05'],
    },
    <String, dynamic>{
      'day_type': 'saturday',
      'origin': 'Aroeira',
      'times': <String>['06:00', '12:40'],
    },
    <String, dynamic>{
      'day_type': 'sunday_holiday',
      'origin': 'Aroeira',
      'times': <String>['07:00'],
    },
  ],
);

/// Line with two origins, so the origin chips appear.
const StaticLine twoOrigins = StaticLine(
  id: 2,
  code: 'two',
  short: '2',
  name: 'Dois / Cohab',
  pilot: true,
  terminals: <String>['Aroeira', 'Cohab'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Aroeira',
      'times': <String>['05:30', '14:35'],
    },
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Cohab',
      'times': <String>['06:20', '15:10'],
    },
  ],
);

/// Line with no schedules at all.
const StaticLine noSchedules = StaticLine(
  id: 3,
  code: 'three',
  short: '3',
  name: 'Tres / Sem Horarios',
  pilot: false,
  schedules: <Map<String, dynamic>>[],
);

/// A Wednesday at noon: the weekday tab is the default.
final DateTime wednesdayNoon = DateTime.utc(2026, 10, 14, 12, 0);

void main() {
  testWidgets('renders the three day types and the next departure hero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableTab(line: oneOrigin, now: wednesdayNoon),
        ),
      ),
    );
    await tester.pump();
    // Wednesday noon: the weekday tab carries the `hoje` mark.
    expect(
      find.text('${UiStrings.dayWeekday} · ${UiStrings.todayMark}'),
      findsOneWidget,
    );
    expect(find.text(UiStrings.daySaturday), findsOneWidget);
    expect(find.text(UiStrings.daySunday), findsOneWidget);
    // Next departure after 12:00 is 14:35.
    expect(find.text('14:35'), findsWidgets);
    expect(find.text(UiStrings.certaintyScheduled), findsOneWidget);
    expect(find.text(UiStrings.originLabel), findsNothing);
  });

  testWidgets('origin chips appear and switch the rail content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableTab(line: twoOrigins, now: wednesdayNoon),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(UiStrings.originLabel), findsOneWidget);
    expect(find.text('Aroeira'), findsOneWidget);
    expect(find.text('Cohab'), findsOneWidget);
    await tester.tap(find.text('Cohab'));
    // The hero ETA cross-fades over 140 ms, so run the tap frame and then
    // advance past the transition before asserting the old time is gone.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The hero moves to 15:10, the next departure from Cohab.
    expect(find.text('15:10'), findsWidgets);
    expect(find.text('05:30'), findsNothing);
  });

  testWidgets('saturday tab shows the saturday rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableTab(line: oneOrigin, now: wednesdayNoon),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(UiStrings.daySaturday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(UiStrings.daySaturday), findsOneWidget);
    // The first weekday time is gone from the rail.
    expect(find.text('05:30'), findsNothing);
  });

  testWidgets('empty state when the day has no schedules', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableTab(line: noSchedules, now: wednesdayNoon),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(UiStrings.timetableEmpty), findsOneWidget);
  });
}

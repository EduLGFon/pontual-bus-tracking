// Widget tests for the global stop sheet: fixed terminal departures and
// honest live prediction states. Hermetic: every provider is overridden.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/learning/global_stop.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/features/line/stop_sheet.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

const StaticLine lineSeven = StaticLine(
  id: 7,
  code: 'seven',
  short: '7',
  name: 'Sete / Centro',
  pilot: true,
  terminals: <String>['Aroeira'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Aroeira',
      'times': <String>['05:30', '06:10', '14:35', '19:05'],
    },
  ],
);

const StaticLine lineEight = StaticLine(
  id: 8,
  code: 'eight',
  short: '8',
  name: 'Oito / Cohab',
  pilot: false,
  terminals: <String>['Cohab'],
  schedules: <Map<String, dynamic>>[],
);

const StaticLine lineEarly = StaticLine(
  id: 9,
  code: 'nine',
  short: '9',
  name: 'Nove / Centro',
  pilot: false,
  terminals: <String>['Centro'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Centro',
      'times': <String>['05:30'],
    },
  ],
);

const GlobalStop stop = GlobalStop(
  id: 'stop-1',
  lat: -18.72,
  lng: -39.85,
  name: 'Ponto Central',
  lines: <StopLineRef>[
    StopLineRef(lineId: 7, direction: 0, stopId: 'member-7'),
    StopLineRef(lineId: 8, direction: 0, stopId: 'member-8'),
  ],
);

final DateTime fixedNow = DateTime.utc(2026, 10, 14, 12, 0);

Widget _app({
  StopArrivals? arrivals,
  bool arrivalsError = false,
  List<StaticLine> lines = const <StaticLine>[lineSeven, lineEight],
  GlobalStop? stopOverride,
}) {
  final StreamController<int> ticks = StreamController<int>.broadcast();
  addTearDown(ticks.close);
  final GlobalStop target = stopOverride ?? stop;
  return ProviderScope(
    overrides: <Override>[
      linesProvider.overrideWith((Ref ref) async => lines),
      currentNowProvider.overrideWithValue(fixedNow),
      vehicleTickProvider.overrideWith((Ref ref) => ticks.stream),
      stopArrivalsProvider(target.id).overrideWith((Ref ref) async {
        if (arrivalsError) {
          throw const StopArrivalsFailure();
        }
        return arrivals;
      }),
    ],
    child: MaterialApp(
      home: Scaffold(body: StopSheet(stop: target)),
    ),
  );
}

void main() {
  testWidgets('shows fixed terminal times and a live prediction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        arrivals: const StopArrivals(
          stopId: 'stop-1',
          nowS: 1730000000,
          items: <StopArrivalItem>[
            StopArrivalItem(
              lineId: 8,
              code: 'eight',
              vehicleId: 12,
              etaS: 240,
              confidence: 'high',
              sampleCount: 10,
              method: 'learned',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ponto Central'), findsOneWidget);
    expect(find.text(UiStrings.stopFixedLabel), findsNWidgets(2));
    // Wednesday noon: the next two terminal departures for line 7.
    expect(find.text('14:35'), findsOneWidget);
    expect(find.text('19:05'), findsOneWidget);
    expect(find.text(UiStrings.stopPredictionLabel), findsNWidgets(2));
    expect(find.text('~4 min'), findsOneWidget);
    // Line 8 has no schedules at all, so the copy does not imply earlier
    // departures existed.
    expect(find.text(UiStrings.stopNoSchedules), findsOneWidget);
    // Line 7 has no live item.
    expect(find.text(UiStrings.stopNoPrediction), findsOneWidget);
  });

  testWidgets('a line with schedules but none left says no more today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        lines: const <StaticLine>[lineEarly],
        stopOverride: const GlobalStop(
          id: 'stop-2',
          lat: -18.72,
          lng: -39.85,
          name: 'Ponto Cedo',
          lines: <StopLineRef>[
            StopLineRef(lineId: 9, direction: 0, stopId: 'member-9'),
          ],
        ),
        arrivals: const StopArrivals(
          stopId: 'stop-2',
          nowS: 1730000000,
          items: <StopArrivalItem>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(UiStrings.stopNoFixed), findsOneWidget);
    expect(find.text(UiStrings.stopNoSchedules), findsNothing);
  });

  testWidgets('a passed item is not shown as approaching', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        arrivals: const StopArrivals(
          stopId: 'stop-1',
          nowS: 1730000000,
          items: <StopArrivalItem>[
            StopArrivalItem(
              lineId: 7,
              code: 'seven',
              vehicleId: 12,
              etaS: 30,
              confidence: 'high',
              sampleCount: 10,
              method: 'passed',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(UiStrings.stopNow), findsNothing);
    expect(find.text(UiStrings.stopNoPrediction), findsNWidgets(2));
  });

  testWidgets('a fallback sentinel alone is not shown as Agora', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        arrivals: const StopArrivals(
          stopId: 'stop-1',
          nowS: 1730000000,
          items: <StopArrivalItem>[
            StopArrivalItem(
              lineId: 7,
              code: 'seven',
              vehicleId: 12,
              etaS: 0,
              confidence: 'low',
              sampleCount: 0,
              method: 'fallback',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(UiStrings.stopNow), findsNothing);
    expect(find.text(UiStrings.stopNoPrediction), findsNWidgets(2));
  });

  testWidgets('a fallback sentinel does not mask a real learned bus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        arrivals: const StopArrivals(
          stopId: 'stop-1',
          nowS: 1730000000,
          items: <StopArrivalItem>[
            StopArrivalItem(
              lineId: 8,
              code: 'eight',
              vehicleId: 12,
              etaS: 0,
              confidence: 'low',
              sampleCount: 0,
              method: 'fallback',
            ),
            StopArrivalItem(
              lineId: 8,
              code: 'eight',
              vehicleId: 13,
              etaS: 240,
              confidence: 'high',
              sampleCount: 10,
              method: 'learned',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(UiStrings.stopNow), findsNothing);
    expect(find.text('~4 min'), findsOneWidget);
  });

  testWidgets('a failed arrivals request shows the honest failure state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(arrivalsError: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(UiStrings.stopFetchFailed), findsNWidgets(2));
    expect(find.text(UiStrings.stopNoPrediction), findsNothing);
  });

  testWidgets('no known lines is an honest empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          linesProvider.overrideWith((Ref ref) async => const <StaticLine>[]),
          currentNowProvider.overrideWithValue(fixedNow),
          vehicleTickProvider.overrideWith(
            (Ref ref) => const Stream<int>.empty(),
          ),
          stopArrivalsProvider('stop-1').overrideWith((Ref ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StopSheet(
              stop: GlobalStop(id: 'stop-1', lat: -18.72, lng: -39.85),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(UiStrings.stopTitle), findsOneWidget);
    expect(find.text(UiStrings.stopNoLines), findsOneWidget);
  });
}

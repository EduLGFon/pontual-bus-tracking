import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/learning/eta_estimate.dart';
import 'package:pontual/domain/learning/learned_stop.dart';
import 'package:pontual/ui/features/line/line_screen.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'line_screen_test.dart' show pilotLine, liveBus, overridesFor;

class _FakeFixController extends ViewerFixController {
  @override
  ViewerFixState build() => ViewerFixState(
    status: ViewerFixStatus.ready,
    position: const LatLng(-18.72, -39.85),
    accuracyM: 20,
    at: DateTime.now(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('ready personal arrival shows card header and row', (
    tester,
  ) async {
    const LearnedStop stop = LearnedStop(
      id: 'stop-a',
      ordinal: 0,
      lat: -18.72,
      lng: -39.85,
      radiusM: 30,
      passes: 5,
    );
    final List<Override> overrides = <Override>[
      ...overridesFor(
        const <StaticLine>[pilotLine],
        const <int, List<ClientVehicle>>{
          7: <ClientVehicle>[liveBus],
        },
      ),
      viewerFixProvider.overrideWith(_FakeFixController.new),
      learnedStopsProvider(7).overrideWith(
        (Ref ref) async => const LearnedStopsResult(
          direction: 0,
          stops: <LearnedStop>[stop],
          fallback: false,
        ),
      ),
      etaProvider((lineId: 7, stopId: 'stop-a')).overrideWith(
        (Ref ref) async => const EtaResult(
          stopId: 'stop-a',
          nowS: 0,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 3,
              etaS: 360,
              confidence: 'medium',
              sampleCount: 12,
            ),
          ],
        ),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.scrollUntilVisible(find.text(UiStrings.myStopEta(6)), 200);
    expect(find.text(UiStrings.myStopEta(6)), findsOneWidget);
    expect(find.text(UiStrings.myStopHeaderEta(6)), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(UiStrings.myStopEtaUntilYou(6)),
      200,
    );
    expect(find.text(UiStrings.myStopEtaUntilYou(6)), findsOneWidget);
  });

  testWidgets('no fix shows prompt and opens privacy sheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const <StaticLine>[
          pilotLine,
        ], const <int, List<ClientVehicle>>{}),
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(UiStrings.myStopEnable), findsOneWidget);
    await tester.tap(find.text(UiStrings.myStopEnable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(UiStrings.myStopPrivacyTitle), findsOneWidget);
  });

  testWidgets('fix but no stops shows no stops', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(const <StaticLine>[
            pilotLine,
          ], const <int, List<ClientVehicle>>{}),
          viewerFixProvider.overrideWith(_FakeFixController.new),
          learnedStopsProvider(7).overrideWith(
            (Ref ref) async => const LearnedStopsResult(
              direction: 0,
              stops: <LearnedStop>[],
              fallback: false,
            ),
          ),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(UiStrings.myStopNoStops), findsOneWidget);
  });
}

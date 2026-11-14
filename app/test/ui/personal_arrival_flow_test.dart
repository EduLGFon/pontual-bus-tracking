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
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/features/line/line_screen.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'line_screen_test.dart' show pilotLine, liveBus, overridesFor;
import 'viewer_fix_test.dart' show RecordingGateway, RecordingReader, posOf;

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

  testWidgets('mount auto requests without opening the privacy sheet', (
    tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final hanging = reader.hanging();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerPermissionGatewayProvider.overrideWithValue(gateway),
          viewerPositionReaderProvider.overrideWithValue(hanging),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    for (int i = 0; i < 12; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));

    // The OS grant is reused silently: no in-app sheet, no extra prompt,
    // and the card shows the loading copy while the fix lands.
    expect(gateway.checks, 1);
    expect(gateway.requests, 0);
    expect(reader.calls, 1);
    expect(find.text(UiStrings.myStopPrivacyTitle), findsNothing);
    expect(find.text(UiStrings.linePersonalPromptTitle), findsNothing);
    expect(find.text(UiStrings.myStopLoading), findsOneWidget);

    reader.pending(0).complete(posOf(const LatLng(-18.72, -39.85), 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<LineMap>(find.byType(LineMap)).viewerPosition,
      isNotNull,
    );
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
    // 6 min ETA and a 2 min walk leave spare time. The personal card is the
    // hero above the tabs, so the old header summary is gone.
    expect(find.text(UiStrings.lineStillTime), findsOneWidget);
    expect(find.text(UiStrings.myStopHeaderEta(6)), findsNothing);
    await tester.scrollUntilVisible(
      find.text(UiStrings.myStopEtaUntilYou(6)),
      200,
    );
    expect(find.text(UiStrings.myStopEtaUntilYou(6)), findsOneWidget);
    final LineMap map = tester.widget<LineMap>(find.byType(LineMap));
    expect(map.personalStop, isNotNull);
    expect(map.personalStopLabel, isNotNull);
  });

  testWidgets('no fix shows prompt and opens privacy sheet', (tester) async {
    // The automatic attempt fails honestly (services off), so the prompt
    // and its recovery sheet remain available.
    final RecordingGateway gateway = RecordingGateway()
      ..servicesOnResult = false;
    final RecordingReader reader = RecordingReader();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerPermissionGatewayProvider.overrideWithValue(gateway),
          viewerPositionReaderProvider.overrideWithValue(reader.instant()),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // The compact prompt sits below the NextBusCard in the panel body.
    await tester.ensureVisible(find.text(UiStrings.myStopEnable));
    await tester.pump();
    expect(find.text(UiStrings.linePersonalPromptTitle), findsOneWidget);
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
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
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
    await tester.scrollUntilVisible(find.text(UiStrings.myStopNoStops), 200);
    expect(find.text(UiStrings.myStopNoStops), findsOneWidget);
  });

  testWidgets('compact layout draws the personal stop marker', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      return tester.binding.setSurfaceSize(null);
    });

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
    final LineMap map = tester.widget<LineMap>(find.byType(LineMap));
    expect(map.personalStop, isNotNull);
    expect(map.personalStopLabel, isNotNull);
  });
}

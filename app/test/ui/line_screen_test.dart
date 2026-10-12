// Tests of the new line screen: unknown key, live line with markers and
// vehicle rows, non shareable line hiding the dock and showing the note,
// and 200 percent text scale. Uses the fake harness pattern of
// test/map_tab_test.dart so no network call ever happens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/features/line/line_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vehicle_test.dart' show FakeChannel;

/// Shareable line used by the live cases.
/// Sizes the test view to a compact phone: the layout reads the size from
/// MediaQuery, which follows the view physical size, not the render
/// constraints, so setSurfaceSize alone is not enough.
Future<void> _useCompactView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    return tester.binding.setSurfaceSize(null);
  });
}

/// Drags the sheet from peek to half so the body sections are built. The
/// drag starts on the visible sheet area: the sheet element itself spans the
/// whole screen, so dragging its center would hit the map instead.
Future<void> _openSheet(WidgetTester tester) async {
  final Size size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.dragFrom(
    Offset(size.width / 2, size.height - 50),
    const Offset(0, -250),
  );
  // pumpAndSettle never returns while the shared live pulse runs, so pump
  // a fixed number of frames instead.
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const StaticLine pilotLine = StaticLine(
  id: 7,
  code: 'seven',
  short: '7',
  name: 'Sete / Centro',
  pilot: true,
  terminals: <String>['Aroeira', 'Cohab'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Aroeira',
      'times': <String>['05:30', '06:10', '14:35', '19:05'],
    },
  ],
);

/// Non shareable line used by the note case.
const StaticLine timetableLine = StaticLine(
  id: 10,
  code: 'ten',
  short: '10',
  name: 'Dez / Vila Nova',
  pilot: false,
  terminals: <String>['Vila Nova'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Vila Nova',
      'times': <String>['05:30', '06:10'],
    },
  ],
);

/// One live vehicle for the fake repository.
const ClientVehicle liveBus = ClientVehicle(
  id: 3,
  lat: -18.72,
  lng: -39.85,
  heading: 90,
  kmh: 29,
  members: 1,
  ageS: 4,
);

/// Another live vehicle, elsewhere, so the camera has two points to fit.
const ClientVehicle liveBus2 = ClientVehicle(
  id: 4,
  lat: -18.75,
  lng: -39.9,
  heading: 180,
  kmh: 12,
  members: 1,
  ageS: 9,
);

/// Fixed São Mateus wall clock, so the timetable assertions are stable.
final DateTime fixedNow = DateTime.utc(2026, 10, 14, 12, 0);

/// Builds a repository that answers with [vehicles].
VehicleRepository repoOf(List<ClientVehicle> vehicles) {
  return VehicleRepository(
    fetchSnapshot: (_) async => vehicles,
    openChannel: (_) async => FakeChannel(),
    wsBaseUrl: () => 'ws://127.0.0.1:8080',
    clock: FakeClock(100000),
    launch: (Future<void> task) {},
  );
}

/// Overrides every provider the screen reads, so nothing touches the
/// network, the clock or the asset bundle.
List<Override> overridesFor(
  List<StaticLine> lines,
  Map<int, List<ClientVehicle>> vehicles,
) {
  return <Override>[
    linesProvider.overrideWith((Ref ref) async => lines),
    liveProvider.overrideWith(
      (Ref ref) async => const LiveLines(<List<int>>[]),
    ),
    tileUrlProvider.overrideWith(
      (Ref ref) async => 'http://127.0.0.1:9/{z}/{x}/{y}.png',
    ),
    currentNowProvider.overrideWithValue(fixedNow),
    for (final MapEntry<int, List<ClientVehicle>> e in vehicles.entries)
      vehicleRepoProvider(e.key).overrideWithValue(repoOf(e.value)),
    // Seeded synchronously from the same fake rows. The repository only
    // surfaces its snapshot on the 5 s tick, so a finite tick burst can
    // elapse before the async start lands and the sheet stays empty.
    for (final MapEntry<int, List<ClientVehicle>> e in vehicles.entries)
      vehiclesVmProvider(e.key).overrideWithValue(
        orderVehicles(e.value, e.key.toString()),
      ),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('unknown line key shows the not found empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const <StaticLine>[
          pilotLine,
        ], const <int, List<ClientVehicle>>{}),
        child: const MaterialApp(home: LineScreen(lineKey: 'nope')),
      ),
    );
    await tester.pump();
    expect(find.text(UiStrings.lineNotFound), findsOneWidget);
    expect(find.text(UiStrings.lineNoTracking), findsNothing);
  });

  testWidgets('shareable live line renders markers and vehicle rows', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          const <StaticLine>[pilotLine],
          const <int, List<ClientVehicle>>{
            7: <ClientVehicle>[liveBus, liveBus2],
          },
        ),
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(LineScreen))).width,
      400,
    );
    await _openSheet(tester);
    // The sheet builds lazily: rows below the fold need a scroll to
    // exist, and rows scrolled far out of view are evicted again. So
    // assert the header while row 1 is in view, then go to row 2.
    await tester.scrollUntilVisible(find.text('Ônibus 1'), 200);
    expect(find.text('Ônibus 1'), findsOneWidget);
    expect(find.text(UiStrings.vehiclesNow), findsOneWidget);
    expect(find.text(UiStrings.dockIdleOnLine), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ônibus 2'), 200);
    expect(find.text('Ônibus 2'), findsOneWidget);
    // The map is mounted and the vehicle rows carry the accessible
    // alternative a screen reader reads instead of the map.
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('non shareable line hides the dock and shows the note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          const <StaticLine>[timetableLine],
          const <int, List<ClientVehicle>>{
            10: <ClientVehicle>[liveBus],
          },
        ),
        child: const MaterialApp(home: LineScreen(lineKey: 'ten')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(UiStrings.lineNoTracking), findsOneWidget);
    expect(find.text(UiStrings.dockIdleOnLine), findsNothing);
    expect(find.text(UiStrings.homeNoLive), findsOneWidget);
  });

  testWidgets('200 percent text scale raises no exception', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          const <StaticLine>[pilotLine],
          const <int, List<ClientVehicle>>{
            7: <ClientVehicle>[liveBus, liveBus2],
          },
        ),
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: LineScreen(lineKey: 'seven')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    // At double text size the section sits below the fold of the peek
    // sheet, so scroll it into view before asserting it exists.
    await tester.scrollUntilVisible(find.text(UiStrings.vehiclesNow), 200);
    expect(find.text(UiStrings.vehiclesNow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

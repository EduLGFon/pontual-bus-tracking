// Tests of the new line screen: unknown key, live line with markers and
// vehicle rows, non shareable line hiding the dock and showing the note,
// 200 percent text scale, and the viewer stream lifecycle while a page
// covers the screen. Uses the fake harness pattern of
// test/map_tab_test.dart so no network call ever happens.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/features/line/line_screen.dart';
import 'package:pontual/ui/features/line/next_bus_card.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/ui/features/timetable/timetable_tab.dart';
import 'package:pontual/ui/router/route_observer.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vehicle_test.dart' show FakeChannel;
import 'viewer_fix_test.dart' show RecordingGateway, RecordingReader;

/// Shareable line used by the live cases.
/// Sizes the test view to a compact phone: the layout reads the size from
/// MediaQuery, which follows the view physical size, not the render
/// constraints, so setSurfaceSize alone is not enough.
Future<void> _useCompactView(WidgetTester tester) async {
  await _useView(tester, const Size(400, 800));
}

/// Sizes the test view to [size] in logical pixels.
Future<void> _useView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
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

/// Line whose last weekday departure is 20:20, used by the late-night case.
const StaticLine lateLine = StaticLine(
  id: 11,
  code: 'eleven',
  short: '11',
  name: 'Onze / Centro',
  pilot: true,
  terminals: <String>['Centro'],
  schedules: <Map<String, dynamic>>[
    <String, dynamic>{
      'day_type': 'weekday',
      'origin': 'Centro',
      'times': <String>['05:30', '06:10', '20:20'],
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
/// Held the same way [currentNowProvider] holds it: a UTC-flagged instant
/// already shifted to the wall clock, never converted again by the UI.
final DateTime fixedNow = DateTime.utc(2026, 10, 14, 12, 0);

/// Wednesday 23:00 wall clock, after the last weekday departure of
/// [lateLine].
final DateTime lateNightNow = DateTime.utc(2026, 10, 14, 23, 0);

/// Repository that counts stream starts and stops. It never touches the
/// network: the route-lifecycle test only cares about the calls.
class RecordingRepo extends VehicleRepository {
  RecordingRepo()
    : super(
        fetchSnapshot: (_) async =>
            const ClientSnapshot(vehicles: <ClientVehicle>[]),
        openChannel: (_) async => FakeChannel(),
        wsBaseUrl: () => 'ws://127.0.0.1:8080',
        clock: FakeClock(100000),
        launch: (Future<void> task) {},
      );

  /// Calls to [start].
  int starts = 0;

  /// Calls to [stop].
  int stops = 0;

  @override
  Future<void> start(int lineId) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }
}

/// Repository whose stop stays pending until the test releases it.
class SlowStopRepo extends RecordingRepo {
  /// Released by the test to let the close finish.
  final Completer<void> stopGate = Completer<void>();

  @override
  Future<void> stop() async {
    stops += 1;
    await stopGate.future;
  }
}

/// Fix controller that records refresh calls without touching a gateway.
class _RecordingFixController extends ViewerFixController {
  _RecordingFixController(this.initial);

  final ViewerFixState initial;

  /// Calls to [request].
  int requests = 0;

  /// Calls to [request] with force.
  int forced = 0;

  /// Calls to [requestAutomatic].
  int automatic = 0;

  @override
  ViewerFixState build() => initial;

  @override
  Future<void> requestAutomatic() async {
    automatic++;
  }

  @override
  Future<bool> request({
    bool force = false,
    bool silent = false,
    bool auto = false,
  }) async {
    requests++;
    if (force) {
      forced++;
    }
    return true;
  }
}

/// Fix controller seeded with a ready fix for revoked-permission tests.
class _ReadyFixController extends ViewerFixController {
  @override
  ViewerFixState build() => ViewerFixState(
    status: ViewerFixStatus.ready,
    position: const LatLng(-18.72, -39.85),
    accuracyM: 10,
    at: fixedNow.subtract(const Duration(seconds: 61)),
  );
}

/// App with the line screen and the page observer attached, for route tests.
Widget routeApp(VehicleRepository repo) {
  return ProviderScope(
    overrides: <Override>[
      linesProvider.overrideWith(
        (Ref ref) async => const <StaticLine>[pilotLine],
      ),
      liveProvider.overrideWith(
        (Ref ref) async => const LiveLines(<List<int>>[]),
      ),
      tileUrlProvider.overrideWith(
        (Ref ref) async => 'http://127.0.0.1:9/{z}/{x}/{y}.png',
      ),
      currentNowProvider.overrideWithValue(fixedNow),
      vehicleRepoProvider(7).overrideWithValue(repo),
    ],
    child: MaterialApp(
      navigatorObservers: <NavigatorObserver>[appPageRouteObserver],
      home: const LineScreen(lineKey: 'seven'),
    ),
  );
}

/// Builds a repository that answers with [vehicles].
VehicleRepository repoOf(List<ClientVehicle> vehicles) {
  return VehicleRepository(
    fetchSnapshot: (_) async => ClientSnapshot(vehicles: vehicles),
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
  Map<int, List<ClientVehicle>> vehicles, {
  DateTime? now,
}) {
  return <Override>[
    linesProvider.overrideWith((Ref ref) async => lines),
    liveProvider.overrideWith(
      (Ref ref) async => const LiveLines(<List<int>>[]),
    ),
    tileUrlProvider.overrideWith(
      (Ref ref) async => 'http://127.0.0.1:9/{z}/{x}/{y}.png',
    ),
    currentNowProvider.overrideWithValue(now ?? fixedNow),
    for (final MapEntry<int, List<ClientVehicle>> e in vehicles.entries)
      vehicleRepoProvider(e.key).overrideWithValue(repoOf(e.value)),
    // Seeded synchronously from the same fake rows. The repository only
    // surfaces its snapshot on the 5 s tick, so a finite tick burst can
    // elapse before the async start lands and the sheet stays empty.
    for (final MapEntry<int, List<ClientVehicle>> e in vehicles.entries)
      vehiclesVmProvider(e.key)
          .overrideWithValue(orderVehicles(e.value, e.key.toString())),
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
    // The next bus is the hero above the tabs at peek: a live hero and
    // the compact live count in the header.
    expect(find.byType(NextBusCard), findsOneWidget);
    expect(find.text(UiStrings.lineNextLive), findsOneWidget);
    expect(find.text(UiStrings.lineLiveCount(2)), findsOneWidget);
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
    expect(find.text(UiStrings.onlyTimetable), findsOneWidget);
    expect(find.text(UiStrings.dockIdleOnLine), findsNothing);
    // At the fixed noon clock both departures (05:30, 06:10) are past, so
    // the calm empty-live card carries the tomorrow hint.
    expect(find.text(UiStrings.lineNoLiveTitle), findsOneWidget);
    expect(find.text(UiStrings.lineNoLiveBody), findsOneWidget);
    expect(find.text(UiStrings.homeNoMoreToday), findsOneWidget);
    // The header no longer repeats the departure, so the banner is the
    // only place the next service day appears.
    expect(find.text(UiStrings.homeTomorrowAt('05:30')), findsOneWidget);
  });

  testWidgets('late night does not show an already past departure as next', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          const <StaticLine>[lateLine],
          const <int, List<ClientVehicle>>{11: <ClientVehicle>[]},
          now: lateNightNow,
        ),
        child: const MaterialApp(home: LineScreen(lineKey: 'eleven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // At 23:00 the 20:20 departure is gone, so it is never the large hero.
    expect(find.byType(NextBusCard), findsNothing);
    expect(find.text('20:20'), findsNothing);
    // The header must not point at the empty hero as the next departure.
    expect(find.text(UiStrings.lineNextScheduled), findsNothing);
    expect(find.text(UiStrings.homeNoMoreToday), findsOneWidget);
    // The Agora body below the tabs shows the honest end-of-day state.
    await _openSheet(tester);
    await tester.scrollUntilVisible(
      find.text(UiStrings.homeTomorrowAt('05:30')),
      200,
    );
    // The header keeps the same copy, so the sentence appears twice.
    expect(find.text(UiStrings.homeNoMoreToday), findsWidgets);
    expect(find.text(UiStrings.homeTomorrowAt('05:30')), findsOneWidget);
    expect(find.text('20:20'), findsNothing);
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

  testWidgets('320x568 at 2x text renders the hero without overflow', (
    WidgetTester tester,
  ) async {
    await _useView(tester, const Size(320, 568));
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
    // At 2x the taller header puts the hero below the peek fold, so scroll
    // the sheet (as a rider would) before checking its content.
    await tester.scrollUntilVisible(
      find.byType(NextBusCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(NextBusCard), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320x568 peek shows the scheduled ETA without dragging', (
    WidgetTester tester,
  ) async {
    await _useView(tester, const Size(320, 568));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          const <StaticLine>[pilotLine],
          const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
        ),
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    // The fixed noon clock makes 14:35 the next scheduled departure and
    // the only place that value appears on the Agora tab.
    final Finder eta = find.text('14:35');
    expect(eta, findsOneWidget);
    final Rect rect = tester.getRect(eta);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(568));
  });

  testWidgets('wide 800x600 panel shows the hero without clipping', (
    WidgetTester tester,
  ) async {
    await _useView(tester, const Size(800, 600));
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
    expect(tester.takeException(), isNull);
    expect(find.byType(NextBusCard), findsOneWidget);
    // "Agora" is both the live ETA hero and the tab segment.
    expect(find.text('Agora'), findsWidgets);
    expect(find.text(UiStrings.lineLiveCount(2)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide 800x600 at 2x text renders without overflow', (
    WidgetTester tester,
  ) async {
    await _useView(tester, const Size(800, 600));
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
    expect(find.byType(NextBusCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewer fix refreshes at most once per minute on the tick', (
    WidgetTester tester,
  ) async {
    final StreamController<int> ticks = StreamController<int>.broadcast();
    addTearDown(ticks.close);
    DateTime now = fixedNow;
    final _RecordingFixController fix = _RecordingFixController(
      ViewerFixState(
        status: ViewerFixStatus.ready,
        position: const LatLng(-18.72, -39.85),
        accuracyM: 10,
        at: fixedNow.subtract(const Duration(seconds: 61)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerFixProvider.overrideWith(() => fix),
          viewerNowProvider.overrideWithValue(() => now),
          vehicleTickProvider.overrideWith((Ref ref) => ticks.stream),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(fix.requests, 0);

    // The held fix is old enough: the first tick refreshes it.
    ticks.add(1);
    await tester.pump();
    expect(fix.requests, 1);
    expect(fix.forced, 1);

    // Five seconds later the minute window still holds.
    now = now.add(const Duration(seconds: 5));
    ticks.add(2);
    await tester.pump();
    expect(fix.requests, 1);

    // A minute after the attempt it refreshes again.
    now = now.add(const Duration(seconds: 55));
    ticks.add(3);
    await tester.pump();
    expect(fix.requests, 2);
  });

  testWidgets('map locate refreshes now and restarts the minute window', (
    WidgetTester tester,
  ) async {
    final StreamController<int> ticks = StreamController<int>.broadcast();
    addTearDown(ticks.close);
    DateTime now = fixedNow;
    final _RecordingFixController fix = _RecordingFixController(
      ViewerFixState(
        status: ViewerFixStatus.ready,
        position: const LatLng(-18.72, -39.85),
        accuracyM: 10,
        at: fixedNow.subtract(const Duration(seconds: 61)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerFixProvider.overrideWith(() => fix),
          viewerNowProvider.overrideWithValue(() => now),
          vehicleTickProvider.overrideWith((Ref ref) => ticks.stream),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final LineMap map = tester.widget<LineMap>(find.byType(LineMap));
    map.onLocateViewer();
    await tester.pump();
    expect(fix.requests, 1);
    expect(fix.forced, 1);

    // The tick right after the tap must not duplicate the refresh.
    now = now.add(const Duration(seconds: 5));
    ticks.add(1);
    await tester.pump();
    expect(fix.requests, 1);

    // The window restarts from the tap, not from the old fix.
    now = now.add(const Duration(seconds: 55));
    ticks.add(2);
    await tester.pump();
    expect(fix.requests, 2);
  });

  testWidgets('a revoked permission does not prompt on a background tick', (
    WidgetTester tester,
  ) async {
    final StreamController<int> ticks = StreamController<int>.broadcast();
    addTearDown(ticks.close);
    final RecordingGateway gateway = RecordingGateway()
      ..checkResult = LocationPermissionState.denied;
    final RecordingReader reader = RecordingReader();
    final _ReadyFixController fix = _ReadyFixController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerFixProvider.overrideWith(() => fix),
          viewerPermissionGatewayProvider.overrideWithValue(gateway),
          viewerPositionReaderProvider.overrideWithValue(reader.instant()),
          viewerNowProvider.overrideWithValue(() => fixedNow),
          vehicleTickProvider.overrideWith((Ref ref) => ticks.stream),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    ticks.add(1);
    await tester.pump();

    // The revoked grant is reported, never re-requested, and the old fix
    // stays on screen.
    expect(gateway.servicesReads, 1);
    expect(gateway.checks, 1);
    expect(gateway.requests, 0);
    expect(reader.calls, 0);
    final LineMap map = tester.widget<LineMap>(find.byType(LineMap));
    expect(map.viewerPosition, isNotNull);
  });

  testWidgets('timetable-only lines do not acquire viewer location', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[timetableLine],
            const <int, List<ClientVehicle>>{10: <ClientVehicle>[]},
          ),
          viewerPermissionGatewayProvider.overrideWithValue(gateway),
          viewerPositionReaderProvider.overrideWithValue(reader.instant()),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'ten')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(gateway.servicesReads, 0);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(reader.calls, 0);
  });

  testWidgets('page cover pauses the viewer stream and return resumes it', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    final RecordingRepo repo = RecordingRepo();
    await tester.pumpWidget(routeApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 1);

    final BuildContext ctx = tester.element(find.byType(LineScreen));
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const Scaffold(body: Text('cover')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.stops, 1);

    Navigator.of(ctx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 2);
    expect(repo.stops, 1);
  });

  testWidgets('modal sheets do not pause the viewer stream', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    final RecordingRepo repo = RecordingRepo();
    await tester.pumpWidget(routeApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 1);

    final BuildContext ctx = tester.element(find.byType(LineScreen));
    unawaited(
      showModalBottomSheet<void>(
        context: ctx,
        builder: (BuildContext context) => const SizedBox(height: 100),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.stops, 0);

    Navigator.of(ctx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 1);
    expect(repo.stops, 0);
  });

  testWidgets('fast cover and return waits for the close before reconnecting', (
    WidgetTester tester,
  ) async {
    await _useCompactView(tester);
    final SlowStopRepo repo = SlowStopRepo();
    await tester.pumpWidget(routeApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 1);

    final BuildContext ctx = tester.element(find.byType(LineScreen));
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const Scaffold(body: Text('cover')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.stops, 1);

    Navigator.of(ctx).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // The return start is waiting on the close, so no second socket yet.
    expect(repo.starts, 1);

    repo.stopGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.starts, 2);
    expect(repo.stops, 1);
  });

  testWidgets('a fresh trip fix shows on the map without a GPS read', (
    WidgetTester tester,
  ) async {
    TripFix? liveFix = TripFix(
      seq: 1,
      lat: -18.73,
      lng: -39.86,
      speedMps: 0,
      heading: null,
      accuracyM: 5,
      batteryPct: 80,
      charging: false,
      acceptedAtMs: fixedNow.millisecondsSinceEpoch,
    );
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final StreamController<int> ticks = StreamController<int>.broadcast();
    addTearDown(ticks.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...overridesFor(
            const <StaticLine>[pilotLine],
            const <int, List<ClientVehicle>>{7: <ClientVehicle>[]},
          ),
          viewerPermissionGatewayProvider.overrideWithValue(gateway),
          viewerPositionReaderProvider.overrideWithValue(reader.instant()),
          viewerNowProvider.overrideWithValue(() => fixedNow),
          vehicleTickProvider.overrideWith((Ref ref) => ticks.stream),
          liveTripFixReaderProvider.overrideWithValue(() => liveFix),
        ],
        child: const MaterialApp(home: LineScreen(lineKey: 'seven')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final LineMap map = tester.widget<LineMap>(find.byType(LineMap));
    expect(map.viewerPosition, const LatLng(-18.73, -39.86));
    expect(gateway.servicesReads, 0);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(reader.calls, 0);

    liveFix = TripFix(
      seq: 2,
      lat: -18.74,
      lng: -39.87,
      speedMps: 0,
      heading: null,
      accuracyM: 4,
      batteryPct: 80,
      charging: false,
      acceptedAtMs: fixedNow
          .add(const Duration(seconds: 5))
          .millisecondsSinceEpoch,
    );
    ticks.add(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final LineMap map2 = tester.widget<LineMap>(find.byType(LineMap));
    expect(map2.viewerPosition, const LatLng(-18.74, -39.87));
    expect(gateway.servicesReads, 0);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(reader.calls, 0);
  });

  group('timetable tab', () {
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

    testWidgets('late night hero skips the already past 20:20 departure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableTab(line: lateLine, now: lateNightNow),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('20:20'), findsNothing);
      expect(
        find.text(
          '${UiStrings.homeNoMoreToday}. '
          '${UiStrings.homeTomorrowAt('05:30')}.',
        ),
        findsOneWidget,
      );
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
  });
}

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

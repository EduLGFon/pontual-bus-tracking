// Widget tests for the redesigned trip screen: layout invariants (no
// overlap, tip exactly once), one banner for the primary issue with a
// phone-only device tile, and the pinned stop action with its end
// state. Deterministic clocks, no network, no platform channels.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/features/trip/trip_status.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_rig.dart' as rig;

/// Lines bundle with endpoints for the hero direction chip.
List<StaticLine> testLines() {
  return const <StaticLine>[
    StaticLine(
      id: 7,
      code: '7-test',
      short: '7',
      name: 'Linha 7',
      pilot: true,
      schedules: <Map<String, dynamic>>[],
      terminals: <String>['Litorâneo', 'Aviação'],
    ),
  ];
}

/// Pumps [child] with the test lines and the light theme.
Widget wrapTest(Widget child) {
  return ProviderScope(
    overrides: [linesProvider.overrideWith((Ref ref) async => testLines())],
    child: MaterialApp(theme: pontualLightTheme(), home: child),
  );
}

/// Pumps the trip screen inside a router with a home marker.
Widget wrapRouter(rig.Rig r, int Function() nowMs) {
  final GoRouter router = GoRouter(
    initialLocation: '/trip',
    routes: <GoRoute>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('home-marker')),
      ),
      GoRoute(
        path: '/trip',
        builder: (BuildContext context, GoRouterState state) =>
            TripScreen(controller: r.controller, nowMs: nowMs),
      ),
    ],
  );
  return ProviderScope(
    overrides: [linesProvider.overrideWith((Ref ref) async => testLines())],
    child: MaterialApp.router(theme: pontualLightTheme(), routerConfig: router),
  );
}

/// Rects of the main sections, skipping banners that are not shown.
List<Rect> sectionRects(WidgetTester tester) {
  final List<Rect> rects = <Rect>[];
  for (final String key in <String>[
    'tripHeader',
    'tripHeroSection',
    'tileConnection',
    'tileGps',
    'tileDevice',
    'tripTip',
    'tripStop',
  ]) {
    final Finder finder = find.byKey(ValueKey<String>(key));
    if (finder.evaluate().isNotEmpty) {
      rects.add(tester.getRect(finder));
    }
  }
  return rects;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('IssueDebouncer', () {
    test('holds a new issue for two seconds', () {
      final IssueDebouncer debouncer = IssueDebouncer();
      expect(debouncer.update(SharingIssue.offline, 0), SharingIssue.none);
      expect(debouncer.update(SharingIssue.offline, 1999), SharingIssue.none);
      expect(
        debouncer.update(SharingIssue.offline, 2000),
        SharingIssue.offline,
      );
    });

    test('clearing the issue resets the hold', () {
      final IssueDebouncer debouncer = IssueDebouncer();
      debouncer.update(SharingIssue.offline, 0);
      expect(debouncer.update(SharingIssue.none, 500), SharingIssue.none);
      expect(debouncer.update(SharingIssue.offline, 600), SharingIssue.none);
    });
  });

  group('TripScreen layout', () {
    testWidgets('fits 360x640 with no overlap and one tip', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      int now = 101000;
      await tester.pumpWidget(
        wrapTest(TripScreen(controller: r.controller, nowMs: () => now)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text(UiStrings.tripStop), findsOneWidget);
      expect(find.text(UiStrings.keepAwakeTip), findsOneWidget);
      final List<Rect> rects = sectionRects(tester);
      expect(rects.length, greaterThanOrEqualTo(6));
      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: 'sections $i and $j overlap: ${rects[i]} vs ${rects[j]}',
          );
        }
      }
      r.controller.dispose();
      await r.positions.close();
      now = 0;
    });

    testWidgets('survives 200 percent text scale with the stop pinned', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linesProvider.overrideWith((Ref ref) async => testLines()),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              size: Size(360, 640),
            ),
            child: MaterialApp(
              theme: pontualLightTheme(),
              home: TripScreen(controller: r.controller, nowMs: () => 101000),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(UiStrings.tripStop), findsOneWidget);
      expect(find.text(UiStrings.keepAwakeTip), findsOneWidget);
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('offline shows one banner and a phone-only device tile', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      int now = 101000;
      await tester.pumpWidget(
        wrapTest(TripScreen(controller: r.controller, nowMs: () => now)),
      );
      await tester.pump();
      r.clock.advance(200000);
      now += 200000;
      await r.controller.checkAutoEndForTest();
      await tester.pump();
      // First sight starts the hold; advancing past it flips the banner.
      now += 2500;
      r.controller.confirmStillRiding();
      await tester.pump();
      await tester.pump();
      expect(find.text(UiStrings.roleOffline), findsOneWidget);
      expect(find.text(UiStrings.connOffline), findsOneWidget);
      expect(find.text(UiStrings.deviceScreenOn), findsOneWidget);
      expect(tester.takeException(), isNull);
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('stop ends the trip and the end card dismisses', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(wrapRouter(r, () => 101000));
      await tester.pump();
      await tester.tap(find.text(UiStrings.tripStop));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(UiStrings.endTitle), findsOneWidget);
      expect(find.text(UiStrings.endDone), findsOneWidget);
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('home-marker'), findsOneWidget);
      expect(tester.takeException(), isNull);
      r.controller.dispose();
      await r.positions.close();
    });
  });
}

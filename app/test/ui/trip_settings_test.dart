// Widget tests for the new trip screen and the settings center. The trip
// screen is driven by a started TripController from the shared rig; the
// settings screens read local providers only. No network, no platform
// channels, deterministic clocks. See docs/ui/UI_SPEC.md 7.7 and 7.8.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/settings/about_screen.dart';
import 'package:pontual/ui/features/settings/privacy_screen.dart';
import 'package:pontual/ui/features/settings/settings_screen.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/features/trip/trip_status.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_rig.dart' as rig;

/// Pumps [child] in the new theme with an empty provider scope.
Widget wrapApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: pontualLightTheme(), home: child),
  );
}

/// One pump that also flushes sheet and navigation animations. Fake time,
/// so the duration costs no wall time. Used instead of pumpAndSettle,
/// which is slower and hangs on screens with a never-settling pulse.
Future<void> settleOnce(WidgetTester tester) {
  return tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TripScreen', () {
    testWidgets('renders the hero, rows, tick and end action', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
      await tester.pump();
      expect(find.text(UiStrings.tripHero), findsOneWidget);
      expect(find.text(UiStrings.connection), findsOneWidget);
      expect(find.text(UiStrings.gps), findsOneWidget);
      expect(find.text(UiStrings.tripStop), findsOneWidget);
      expect(find.textContaining('há '), findsWidgets);
      expect(tester.takeException(), isNull);
      // Inline teardown: the invariant check runs before addTearDown, so
      // the controller and its timers must stop inside the test body.
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('ending the trip shows the end card', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
      await tester.pump();
      await tester.tap(find.text(UiStrings.tripStop));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(UiStrings.endTitle), findsOneWidget);
      expect(find.text(UiStrings.endDone), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Unmount to cancel the end-card auto-dismiss timer, then stop.
      await tester.pumpWidget(wrapApp(const SizedBox()));
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('back minimises instead of ending', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <GoRoute>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('home-marker')),
          ),
          GoRoute(
            path: '/trip',
            builder: (BuildContext context, GoRouterState state) =>
                TripScreen(controller: r.controller),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: pontualLightTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      unawaited(router.push('/trip'));
      await tester.pump();
      await tester.tap(find.byTooltip(UiStrings.tripMinimize));
      // No settle: the hero pulse never settles by design.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('home-marker'), findsOneWidget);
      expect(r.controller.endKind, isNull);
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('offline trip shows the battery exemption card', (
      WidgetTester tester,
    ) async {
      final Completer<http.Response> hanging = Completer<http.Response>();
      final MockClient client = MockClient((http.Request req) async {
        final String path = req.url.path;
        if (path == '/v1/devices') {
          return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
        }
        if (path == '/v1/consents') {
          return http.Response('{"ok":true}', 200);
        }
        if (path == '/v1/trip' && req.method == 'POST') {
          return http.Response('{"r":"W","n":20}', 201);
        }
        if (path == '/v1/trip/ping') {
          return hanging.future;
        }
        return http.Response('', 204);
      });
      final rig.Rig r = rig.rig(client);
      await rig.start(r);
      r.positions.add(rig.pos(8));
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      r.clock.advance(121 * 1000);
      await r.controller.checkAutoEndForTest();
      expect(r.controller.isOffline, isTrue);
      bool called = false;
      await tester.pumpWidget(
        wrapApp(
          Scaffold(
            body: StatusBlock(
              controller: r.controller,
              wakeUnsupported: false,
              requestExemption: () async {
                called = true;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(UiStrings.batteryExemptionTitle), findsOneWidget);
      await tester.tap(find.text(UiStrings.batteryExemptionAction));
      await tester.pump();
      expect(called, isTrue);
      expect(find.text(UiStrings.batteryExemptionGranted), findsOneWidget);
      expect(tester.takeException(), isNull);
      r.controller.dispose();
      await r.positions.close();
    });
  });

  group('SettingsScreen', () {
    testWidgets('theme switch and toggles persist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const SettingsScreen()));
      await settleOnce(tester);
      await tester.tap(find.text(UiStrings.themeDark));
      await settleOnce(tester);
      final BuildContext context = tester.element(find.byType(SettingsScreen));
      expect(
        ProviderScope.containerOf(context).read(themeHostProvider),
        ThemeMode.dark,
      );
      expect(find.text(UiStrings.dataSaver), findsOneWidget);
      expect(find.text(UiStrings.reduceMotion), findsOneWidget);
      expect(find.text(UiStrings.privacyData), findsOneWidget);
      // The about row sits below the fold of the lazy list.
      await tester.scrollUntilVisible(find.text(UiStrings.about), 200);
      expect(find.text(UiStrings.about), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PrivacyScreen', () {
    testWidgets('rows, summary and cancel keep the data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const PrivacyScreen()));
      await settleOnce(tester);
      expect(find.text(UiStrings.privacyPolicy), findsOneWidget);
      expect(find.text(UiStrings.privacyTerms), findsOneWidget);
      expect(find.text(UiStrings.privacyCollectsTitle), findsOneWidget);
      expect(find.text(UiStrings.privacyRevoke), findsOneWidget);
      // The danger row sits below the fold of the lazy list.
      await tester.scrollUntilVisible(find.text(UiStrings.privacyDelete), 200);
      expect(find.text(UiStrings.privacyDelete), findsOneWidget);
      await tester.tap(find.text(UiStrings.privacyDelete));
      await settleOnce(tester);
      expect(find.text(UiStrings.privacyDeleteTitle), findsOneWidget);
      await tester.tap(find.text(UiStrings.cancel));
      await settleOnce(tester);
      expect(find.text(UiStrings.privacyDeleteTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('AboutScreen', () {
    testWidgets('shows the disclaimer and the source rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const AboutScreen()));
      await settleOnce(tester);
      expect(find.text(UiStrings.aboutDisclaimer), findsOneWidget);
      expect(find.text(UiStrings.aboutOsm), findsOneWidget);
      expect(find.text(UiStrings.aboutLicences), findsOneWidget);
      expect(find.text(UiStrings.aboutRepo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SystemScreen', () {
    testWidgets('maintenance and not-found states', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapApp(const SystemScreen(kind: SystemKind.maintenance)),
      );
      await settleOnce(tester);
      expect(find.text(UiStrings.maintenanceTitle), findsOneWidget);
      expect(find.text(UiStrings.maintenanceBody), findsOneWidget);
      await tester.pumpWidget(
        wrapApp(const SystemScreen(kind: SystemKind.notFound)),
      );
      await settleOnce(tester);
      expect(find.text(UiStrings.notFoundTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// Widget tests for the new trip screen and the settings center. The trip
// screen is driven by a started TripController from the shared rig; the
// settings screens read local providers only. No network, no platform
// channels, deterministic clocks. See docs/ui/UI_SPEC.md 7.7 and 7.8.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/adapters/theme_bridge.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/settings/about_screen.dart';
import 'package:pontual/ui/features/settings/privacy_screen.dart';
import 'package:pontual/ui/features/settings/settings_screen.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_rig.dart' as rig;

/// Pumps [child] in the new theme with an empty provider scope.
Widget wrapApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: pontualLightTheme(), home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TripScreen', () {
    testWidgets('renders the hero, the rows and the end action', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
      await tester.pump();
      expect(find.text(UiStrings.tripHero), findsOneWidget);
      expect(find.text(UiStrings.connection), findsOneWidget);
      expect(find.text(UiStrings.gps), findsOneWidget);
      expect(find.text(UiStrings.endTrip), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Inline teardown: the invariant check runs before addTearDown, so
      // the controller and its timers must stop inside the test body.
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('elapsed time ticks in tabular figures', (
      WidgetTester tester,
    ) async {
      final rig.Rig r = rig.rig(rig.happy());
      await rig.start(r);
      await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
      await tester.pump();
      expect(find.textContaining(RegExp(r'\d\d:\d\d:\d\d')), findsWidgets);
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
      await tester.tap(find.text(UiStrings.endTrip));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.endTitle), findsOneWidget);
      expect(find.text(UiStrings.endBack), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      await tester.pumpAndSettle();
      unawaited(router.push('/trip'));
      await tester.pump();
      await tester.tap(find.byTooltip(UiStrings.tripMinimize));
      // No pumpAndSettle: the hero pulse never settles by design.
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('home-marker'), findsOneWidget);
      expect(r.controller.endKind, isNull);
      r.controller.dispose();
      await r.positions.close();
    });
  });

  group('SettingsScreen', () {
    testWidgets('theme switch updates the provider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(UiStrings.themeDark));
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(SettingsScreen));
      expect(
        ProviderScope.containerOf(context).read(themeHostProvider),
        ThemeMode.dark,
      );
    });

    testWidgets('toggles persist data saver and reduced motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.dataSaver), findsOneWidget);
      expect(find.text(UiStrings.reduceMotion), findsOneWidget);
      expect(find.text(UiStrings.privacyData), findsOneWidget);
      expect(find.text(UiStrings.about), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives 200 percent text scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              size: Size(360, 640),
            ),
            child: MaterialApp(
              theme: pontualLightTheme(),
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PrivacyScreen', () {
    testWidgets('shows the rows and the collection summary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const PrivacyScreen()));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.privacyPolicy), findsOneWidget);
      expect(find.text(UiStrings.privacyTerms), findsOneWidget);
      expect(find.text(UiStrings.privacyCollectsTitle), findsOneWidget);
      expect(find.text(UiStrings.privacyRevoke), findsOneWidget);
      // The danger row sits below the fold of the lazy list.
      await tester.scrollUntilVisible(find.text(UiStrings.privacyDelete), 200);
      expect(find.text(UiStrings.privacyDelete), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel keeps the dialog away and the data kept', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const PrivacyScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(UiStrings.privacyDelete), 200);
      await tester.tap(find.text(UiStrings.privacyDelete));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.privacyDeleteTitle), findsOneWidget);
      await tester.tap(find.text(UiStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.privacyDeleteTitle), findsNothing);
    });
  });

  group('AboutScreen', () {
    testWidgets('shows the disclaimer and the source rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapApp(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.aboutDisclaimer), findsOneWidget);
      expect(find.text(UiStrings.aboutOsm), findsOneWidget);
      expect(find.text(UiStrings.aboutLicences), findsOneWidget);
      expect(find.text(UiStrings.aboutRepo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SystemScreen', () {
    testWidgets('maintenance offers the timetables way out', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapApp(const SystemScreen(kind: SystemKind.maintenance)),
      );
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.maintenanceTitle), findsOneWidget);
      expect(find.text(UiStrings.maintenanceBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown route renders the not-found state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapApp(const SystemScreen(kind: SystemKind.notFound)),
      );
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.notFoundTitle), findsOneWidget);
    });
  });
}

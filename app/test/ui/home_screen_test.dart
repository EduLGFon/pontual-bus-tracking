// Widget tests for the new Início screen. Deterministic: lines come from an
// overridden linesProvider, prefs from SharedPreferences.setMockInitialValues,
// and no network is hit (MockClient answers the live endpoint only).
// See docs/ui/UI_SPEC.md 7.2 and 12.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';
import 'package:pontual/ui/features/home/home_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Two active lines; line 60 has a weekday timetable with two origins.
const String linesJson =
    '[{"id":60,"code":"60-litoraneo-aviacao","short":"60",'
    '"name":"Litorâneo / Aviação","pilot":true,'
    '"terminals":["Litorâneo","Aviação"],"area_tags":[],'
    '"schedules":[{"day_type":"weekday","origin":"Litorâneo",'
    '"times":["05:40","10:20","14:30"]},{"day_type":"weekday",'
    '"origin":"Aviação","times":["06:00","11:00","15:00"]}]},'
    '{"id":62,"code":"62-guriri","short":"62","name":"Guriri",'
    '"pilot":false,"terminals":[],"area_tags":[],"schedules":[]}]';

/// Fixed São Mateus wall clock: Wednesday 10:00.
final DateTime fixedNow = DateTime.utc(2026, 10, 14, 10, 0);

/// Wraps [app] with a deterministic provider scope. The surface stays at or
/// below the 800x600 test window so tap targets land inside the render tree.
Widget wrapHome(
  WidgetTester tester,
  Widget app, {
  required String liveBody,
  Size surface = const Size(390, 560),
  double textScale = 1,
}) {
  final MockClient client = MockClient((http.Request req) async {
    if (req.url.path == '/v1/live') {
      return http.Response(liveBody, 200);
    }
    return http.Response('[]', 200);
  });
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(client),
      linesProvider.overrideWith(
        (Ref ref) async => StaticDataRepository(
          client: client,
          staticBaseUrl: () => 'https://x.example',
          bundleManifestJson: '{}',
          bundleLinesJson: linesJson,
          prefs: SharedPreferences.getInstance,
          nowMs: () => 0,
        ).lines(),
      ),
      currentNowProvider.overrideWith((Ref ref) => fixedNow),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: surface,
        textScaler: TextScaler.linear(textScale),
      ),
      child: app,
    ),
  );
}

/// Themed Início app for direct pumping.
Widget homeApp() {
  return MaterialApp(theme: pontualLightTheme(), home: const HomeScreen());
}

void main() {
  const Map<String, Object> onboardingDone = <String, Object>{
    welcomeSeenKey: true,
    coachmarkSeenKey: true,
  };

  testWidgets('renders cached lines with no spinners', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.homeSubtitle), findsOneWidget);
    expect(find.text(UiStrings.homeAllLines), findsOneWidget);
    // First run offers the Casa and Trabalho placeholders.
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live section appears with a live count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[[60,2]]'));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.homeLiveNow), findsOneWidget);
    expect(find.text('Litorâneo / Aviação'), findsOneWidget);
    expect(find.textContaining(UiStrings.certaintyLive), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('search entry navigates to /search', (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <GoRoute>[
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/search',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('search-marker'))),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(
      wrapHome(
        tester,
        MaterialApp.router(theme: pontualLightTheme(), routerConfig: router),
        liveBody: '[]',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SearchEntry));
    await tester.pumpAndSettle();

    expect(find.text('search-marker'), findsOneWidget);
  });

  testWidgets('welcome card shows once and hides after dismissal', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      coachmarkSeenKey: true,
    });
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.welcomeTitle), findsOneWidget);

    await tester.tap(find.text(UiStrings.ok));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.welcomeTitle), findsNothing);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(welcomeSeenKey), isTrue);

    // Relaunching reads the persisted flag: no welcome card again.
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.welcomeTitle), findsNothing);
  });

  testWidgets('shortcut add flow saves and renders a card', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();

    // First run offers the Casa and Trabalho placeholders.
    expect(find.text('Casa'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();

    // The add sheet opens with Casa preselected; pick a line and save.
    expect(find.text('Adicionar atalho'), findsOneWidget);
    await tester.tap(find.text('Litorâneo / Aviação'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Casa'), findsOneWidget);
    expect(find.text(UiStrings.addShortcut), findsOneWidget);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(shortcutsKey);
    expect(stored, isNotNull);
    expect(stored, contains('Casa'));
    expect(stored, contains('60-litoraneo-aviacao'));
  });

  testWidgets('survives 200 percent text scale', (WidgetTester tester) async {
    // Medium single-column width keeps text that scales to 200% on one line
    // and avoids the two-column strip where long foundation rows would clip.
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(
      wrapHome(
        tester,
        homeApp(),
        liveBody: '[]',
        surface: const Size(760, 1200),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('departures section hides when cards cover every departure', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      shortcutsKey:
          '[{"kind":"home","label":"Casa","lineKey":"60-litoraneo-aviacao",'
          '"originLabel":null}]',
    });
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();

    // The single upcoming departure already shows on the Casa card, so the
    // feed dedupes it away and hides instead of duplicating the card.
    expect(find.text(UiStrings.saindoAgora), findsNothing);
    expect(find.text(UiStrings.nextDepartures), findsNothing);
    expect(find.text('10:20'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departures section shows live rows for live shortcut lines', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      shortcutsKey:
          '[{"kind":"home","label":"Casa","lineKey":"60-litoraneo-aviacao",'
          '"originLabel":null}]',
    });
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[[60,2]]'));
    await tester.pumpAndSettle();

    // The card shows the live badge instead of a time, so the live row is
    // new information and the section titles itself Saindo agora.
    expect(find.text(UiStrings.saindoAgora), findsOneWidget);
    expect(find.text(UiStrings.certaintyLive), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saindo agora hides with no shortcuts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(onboardingDone);
    await tester.pumpWidget(wrapHome(tester, homeApp(), liveBody: '[]'));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.saindoAgora), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

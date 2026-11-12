// Widget tests for the Início "Sua próxima saída" hero. Deterministic:
// lines are overridden, the clock is fixed, prefs are mocked and the live
// endpoint is answered by a MockClient. See docs/ui/UI_SPEC.md 3, 7.2, 12.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/home/home_next_card.dart';
import 'package:pontual/ui/features/home/home_screen.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _line10 = '10-centro';
const String _line20 = '20-praia';

/// Three active lines. Line 10 has two origins so the shortcut preference
/// is observable; line 20 leaves earlier through the merged timetable.
const List<StaticLine> testLines = <StaticLine>[
  StaticLine(
    id: 10,
    code: _line10,
    short: '10',
    name: 'Centro',
    pilot: true,
    terminals: <String>['Centro', 'Praia'],
    schedules: <Map<String, dynamic>>[
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Centro',
        'times': <String>['10:10', '12:00'],
      },
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Praia',
        'times': <String>['11:30'],
      },
    ],
  ),
  StaticLine(
    id: 20,
    code: _line20,
    short: '20',
    name: 'Praia',
    pilot: false,
    terminals: <String>['Praia'],
    schedules: <Map<String, dynamic>>[
      <String, dynamic>{
        'day_type': 'weekday',
        'origin': 'Praia',
        'times': <String>['10:05', '13:00'],
      },
    ],
  ),
];

/// Fixed Wednesday morning in São Mateus wall clock.
final DateTime fixedMorning = DateTime.utc(2026, 10, 14, 10, 0);

/// Same day at night, when no weekday departure remains.
final DateTime fixedNight = DateTime.utc(2026, 10, 14, 23, 0);

const Map<String, Object> onboardingDone = <String, Object>{
  welcomeSeenKey: true,
  coachmarkSeenKey: true,
};

/// Pumps Início with deterministic data and clock.
Widget wrapHero(
  WidgetTester tester, {
  required DateTime now,
  Size surface = const Size(390, 560),
  double textScale = 1,
  String liveBody = '[]',
}) {
  final MockClient client = MockClient((http.Request req) async {
    return http.Response(req.url.path == '/v1/live' ? liveBody : '[]', 200);
  });
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(client),
      linesProvider.overrideWith((Ref ref) async => testLines),
      currentNowProvider.overrideWith((Ref ref) => now),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: surface,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(theme: pontualLightTheme(), home: const HomeScreen()),
    ),
  );
}

Finder heroText(String text) {
  return find.descendant(
    of: find.byType(NextDepartureHero),
    matching: find.text(text),
  );
}

void main() {
  testWidgets('hero picks the earliest departure across favourites and '
      'shortcuts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      favoritesKey: <String>[_line10],
      shortcutsKey:
          '[{"kind":"work","label":"Trabalho","lineKey":"$_line20",'
          '"originLabel":null}]',
    });
    await tester.pumpWidget(wrapHero(tester, now: fixedMorning));
    await tester.pumpAndSettle();

    expect(find.byType(NextDepartureHero), findsOneWidget);
    expect(heroText(UiStrings.homeNextEyebrow), findsOneWidget);
    // Line 20 leaves at 10:05, earlier than line 10 at 10:10.
    expect(heroText('10:05'), findsOneWidget);
    expect(heroText('Praia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero dedupes a line and prefers the shortcut origin', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      favoritesKey: <String>[_line10],
      shortcutsKey:
          '[{"kind":"home","label":"Casa","lineKey":"$_line10",'
          '"originLabel":"Praia"}]',
    });
    await tester.pumpWidget(wrapHero(tester, now: fixedMorning));
    await tester.pumpAndSettle();

    // The merged timetable would say 10:10; the shortcut origin wins.
    expect(heroText('11:30'), findsOneWidget);
    expect(heroText('10:10'), findsNothing);
    expect(find.byType(NextDepartureHero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero shows the calm no-more-today state for tomorrow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      favoritesKey: <String>[_line10],
    });
    await tester.pumpWidget(wrapHero(tester, now: fixedNight));
    await tester.pumpAndSettle();

    expect(heroText(UiStrings.homeNextNoMore), findsOneWidget);
    expect(heroText(UiStrings.homeNextTomorrow('10:10')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero with live chip survives 320x568 at 2x text', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ...onboardingDone,
      favoritesKey: <String>[_line10, _line20],
      shortcutsKey:
          '[{"kind":"work","label":"Trabalho","lineKey":"$_line10",'
          '"originLabel":"Praia"}]',
    });
    await tester.pumpWidget(
      wrapHero(
        tester,
        now: fixedMorning,
        surface: const Size(320, 568),
        textScale: 2,
        liveBody: '[[20,2]]',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NextDepartureHero), findsOneWidget);
    expect(find.text(UiStrings.homeNextLineLive(2)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-run picker survives 320x568 at 2x text', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      coachmarkSeenKey: true,
    });
    await tester.pumpWidget(
      wrapHero(
        tester,
        now: fixedMorning,
        surface: const Size(320, 568),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(UiStrings.homeWelcomeChoose));
    await tester.pumpAndSettle();

    expect(find.text(UiStrings.homeChooseTitle), findsOneWidget);
    await tester.ensureVisible(find.text(UiStrings.homeChooseSave));
    expect(tester.takeException(), isNull);
  });
}

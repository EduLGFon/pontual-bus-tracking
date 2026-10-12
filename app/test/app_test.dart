// App boot and scale tests for the new UI. The app opens on Início with
// the first-run welcome card, every tab is reachable, and the tree
// survives 200 percent text scale on a narrow screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/main.dart';
import 'package:pontual/ui/shell/bottom_nav.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finds a bottom-navigation item by its label, not a screen title that
/// happens to read the same.
Finder _navItem(String label) {
  return find.descendant(
    of: find.byType(BottomNav),
    matching: find.text(label),
  );
}

/// Pumps the full app with deterministic line data. Widget tests must not
/// depend on rootBundle or the network: asset loads answer once per file
/// and remote fetches are blocked by CORS on `flutter test --platform
/// chrome`, so navigation targets would stay empty there.
Future<void> pumpAppWithLines(WidgetTester tester, {double textScale = 1}) {
  final MockClient httpClient = MockClient((http.Request req) async {
    return http.Response('[]', 200);
  });
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        httpClientProvider.overrideWithValue(httpClient),
        linesProvider.overrideWith(
          (Ref ref) async => StaticDataRepository(
            client: httpClient,
            staticBaseUrl: () => 'https://x.example',
            bundleManifestJson: '{}',
            bundleLinesJson:
                '[{"id":60,"code":"sixty","short":"60","name":"Litoraneo",'
                '"pilot":true,"schedules":[]}]',
            prefs: SharedPreferences.getInstance,
            nowMs: () => 0,
          ).lines(),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const PontualApp(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boots on home with pt-BR copy', (WidgetTester tester) async {
    await pumpAppWithLines(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.wordmark), findsOneWidget);
    expect(find.text(UiStrings.homeSubtitle), findsOneWidget);
    expect(find.text(UiStrings.navHome), findsOneWidget);
    expect(find.text(UiStrings.navLines), findsOneWidget);
    expect(find.text(UiStrings.navSettings), findsOneWidget);
  });

  testWidgets('first run shows the welcome card', (WidgetTester tester) async {
    await pumpAppWithLines(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.welcomeTitle), findsOneWidget);
    await tester.tap(find.text(UiStrings.ok));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.welcomeTitle), findsNothing);
  });

  testWidgets('bottom navigation reaches every tab', (
    WidgetTester tester,
  ) async {
    await pumpAppWithLines(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(_navItem(UiStrings.navLines));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.filterAll), findsOneWidget);
    await tester.tap(_navItem(UiStrings.navSettings));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.sectionAppearance), findsOneWidget);
    await tester.tap(_navItem(UiStrings.navHome));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(UiStrings.homeSubtitle), findsOneWidget);
  });

  testWidgets('survives 200 percent text scale', (WidgetTester tester) async {
    await pumpAppWithLines(tester, textScale: 2);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}

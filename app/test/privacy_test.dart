// T41 tests: collection summary, revoke and delete actions, offline
// honesty, and the end-to-end delete navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/prefs/theme_store.dart';
import 'package:pontual/data/prefs/token_store.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/settings/privacy_actions.dart';
import 'package:pontual/main.dart';
import 'package:pontual/ui/shell/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API double answering delete and trip-end calls.
BusApi apiFor(Future<http.Response> Function(http.Request) handler) {
  String? token;
  return BusApi(
    client: MockClient(handler),
    baseUrl: () => 'http://127.0.0.1:8080',
    readToken: () async => token,
    writeToken: (String t) async => token = t,
  );
}

void main() {
  group('PrivacyActions', () {
    test('delete clears token and prefs when online', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenPrefsKey: 'bm1_x',
        consentVersionKey: 2,
        themeModeKey: 'dark',
      });
      final PrivacyActions actions = PrivacyActions(
        api: apiFor((http.Request req) async {
          if (req.url.path == '/v1/me') {
            return http.Response('', 204);
          }
          return http.Response('{}', 404);
        }),
      );
      expect(await actions.deleteMyData(), DeleteOutcome.deleted);
      expect(await const TokenStore().read(), isNull);
      expect(await const ConsentStore().read(), isNull);
    });

    test('delete without a token just clears local data', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        consentVersionKey: 2,
      });
      final PrivacyActions actions = PrivacyActions(
        api: apiFor((_) async => http.Response('{}', 500)),
      );
      expect(await actions.deleteMyData(), DeleteOutcome.deleted);
      expect(await const ConsentStore().read(), isNull);
    });

    test('offline delete keeps everything', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenPrefsKey: 'bm1_x',
        consentVersionKey: 2,
      });
      final PrivacyActions actions = PrivacyActions(
        api: apiFor((_) async => http.Response('{}', 503)),
      );
      expect(await actions.deleteMyData(), DeleteOutcome.offline);
      expect(await const TokenStore().read(), 'bm1_x');
      expect(await const ConsentStore().read(), 1);
    });

    test('revoke clears consent and ends the trip best-effort', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenPrefsKey: 'bm1_x',
        consentVersionKey: 2,
        consentPostedKey: 1,
      });
      bool ended = false;
      final PrivacyActions actions = PrivacyActions(
        api: apiFor((http.Request req) async {
          if (req.url.path == '/v1/trip') {
            ended = true;
            return http.Response('', 204);
          }
          return http.Response('{}', 404);
        }),
      );
      await actions.revokeConsent();
      expect(ended, isTrue);
      expect(await const ConsentStore().read(), isNull);
      expect(await const ConsentStore().readPosted(), isNull);
    });
  });

  testWidgets('delete end-to-end returns home with data cleared', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      tokenPrefsKey: 'bm1_x',
    });
    // Phone-realistic viewport: the shell breakpoints and the dock
    // geometry follow the view size, not the MediaQuery wrapper.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final MockClient httpClient = MockClient((http.Request req) async {
      if (req.url.path == '/v1/me') {
        return http.Response('', 204);
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(httpClient),
          linesProvider.overrideWith(
            (Ref ref) async => StaticDataRepository(
              client: httpClient,
              staticBaseUrl: () => 'https://x.example',
              bundleManifestJson: '{}',
              bundleLinesJson: '[]',
              prefs: SharedPreferences.getInstance,
              nowMs: () => 0,
            ).lines(),
          ),
          busApiProvider.overrideWith(
            (Ref ref) => BusApi(
              client: httpClient,
              baseUrl: () => 'http://127.0.0.1:8080',
              readToken: const TokenStore().read,
              writeToken: const TokenStore().write,
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: PontualApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Dismiss the first-run card so the tab bar is reachable.
    if (find.text('Entendi').evaluate().isNotEmpty) {
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNav),
        matching: find.text('Ajustes'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Privacidade e dados'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacidade e dados'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Apagar meus dados'), 200);
    await tester.tap(find.text('Apagar meus dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Para onde vamos?'), findsOneWidget);
    expect(await const TokenStore().read(), isNull);
  });
}

// T23 tests: remote flags parsing, refresh rules, system screens.
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String bundle =
    '{"min_app_version":"0.1.0","maintenance":false,"message_pt":"","consent_version":2,"tile_url":"https://t.example/{z}/{x}/{y}.png"}';

int nowMs = 0;

RemoteConfigRepository repo(MockClient client) {
  return RemoteConfigRepository(
    client: client,
    staticBaseUrl: () => 'https://static.example',
    bundleConfigJson: bundle,
    prefs: SharedPreferences.getInstance,
    nowMs: () => nowMs,
  );
}

void main() {
  setUp(() {
    nowMs = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('bundle flags load offline', () async {
    final MockClient client = MockClient((_) async {
      throw StateError('no network');
    });
    final RemoteConfig cfg = await repo(client).current();
    expect(cfg.maintenance, isFalse);
    expect(cfg.consentVersion, 2);
  });

  test('maintenance flag refreshes', () async {
    final RemoteConfigRepository r = repo(
      MockClient((_) async {
        return http.Response(
          '{"min_app_version":"0.1.0","maintenance":true,"message_pt":"Volta já","consent_version":2,"tile_url":"https://t.example/{z}/{x}/{y}.png"}',
          200,
        );
      }),
    );
    nowMs = remoteCheckInterval.inMilliseconds + 1;
    expect(((await r.refresh()) as Ok<bool>).value, isTrue);
    expect((await r.current()).messagePt, 'Volta já');
  });

  test('stale remote consent version cannot downgrade bundled version', () async {
    final RemoteConfigRepository r = repo(
      MockClient((_) async {
        return http.Response(
          '{"min_app_version":"0.1.0","maintenance":false,"message_pt":"",'
          '"consent_version":1,"tile_url":"https://t.example/{z}/{x}/{y}.png"}',
          200,
        );
      }),
    );

    expect(await r.refresh(force: true), isA<Ok<bool>>());
    expect((await r.current()).consentVersion, 2);
  });

  test('corrupt flags keep old values', () async {
    final RemoteConfigRepository r = repo(
      MockClient((_) async {
        return http.Response('nope', 200);
      }),
    );
    nowMs = remoteCheckInterval.inMilliseconds + 1;
    expect(await r.refresh(), isA<Err<bool>>());
    expect((await r.current()).maintenance, isFalse);
  });

  test('version comparison detects old builds', () {
    expect(RemoteConfig.updateRequired('0.1.0', '0.1.0'), isFalse);
    expect(RemoteConfig.updateRequired('0.1.0', '0.2.0'), isTrue);
    expect(RemoteConfig.updateRequired('1.0.0', '0.9.9'), isFalse);
  });

  testWidgets('system screens show per-kind titles', (
    WidgetTester tester,
  ) async {
    for (final SystemKind kind in SystemKind.values) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: pontualLightTheme(),
            home: SystemScreen(kind: kind, message: 'Oi'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Oi'), findsOneWidget);
    }
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: pontualLightTheme(),
          home: const SystemScreen(kind: SystemKind.maintenance),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Serviço em manutenção'), findsOneWidget);
  });

  testWidgets('offline banner announces saved data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: pontualLightTheme(),
          home: const Banner(message: 'Sem conexão. Mostrando dados salvos.'),
        ),
      ),
    );
    expect(find.text('Sem conexão. Mostrando dados salvos.'), findsOneWidget);
  });
}

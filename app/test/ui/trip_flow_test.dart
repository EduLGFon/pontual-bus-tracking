// Widget tests for the new trip flow entry: the line chooser lists only
// sharing-capable lines, dismissing it starts nothing, and a permission
// denial renders the permission card instead of failing silently. The OS
// prompt itself is faked through the gateway seam, so no platform channel
// is ever touched. See docs/ui/UI_SPEC.md 7.7.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/prefs/token_store.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/permission_card.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/trip/trip_flow.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_rig.dart' show MutableGateway;

/// Gateway that records whether the OS prompt was requested.
class RecordingGateway extends MutableGateway {
  /// True after [request] ran once.
  bool requested = false;

  @override
  Future<LocationPermissionState> request() async {
    requested = true;
    return super.request();
  }
}

/// Two lines: only the first supports sharing.
const String linesJson =
    '[{"id":60,"code":"60-litoraneo-aviacao","short":"60",'
    '"name":"Litorâneo / Aviação","pilot":true,'
    '"terminals":["Litorâneo","Aviação"],"area_tags":[],'
    '"schedules":[]},'
    '{"id":62,"code":"62-guriri","short":"62","name":"Guriri",'
    '"pilot":false,"terminals":[],"area_tags":[],"schedules":[]}]';

/// Fixed São Mateus wall clock.
final DateTime fixedNow = DateTime.utc(2026, 10, 14, 10, 0);

/// Scope with deterministic lines, flags, API and prefs.
Widget wrapFlow(Widget app, {required PermissionGateway gateway}) {
  final MockClient client = MockClient((http.Request req) async {
    if (req.url.path == '/v1/live') {
      return http.Response('[]', 200);
    }
    if (req.url.path == '/v1/devices') {
      return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
    }
    if (req.url.path == '/v1/consents') {
      return http.Response('{"ok":true}', 200);
    }
    return http.Response('{}', 404);
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
      remoteConfigRepoProvider.overrideWith(
        (Ref ref) async => RemoteConfigRepository(
          client: client,
          staticBaseUrl: () => 'https://x.example',
          bundleConfigJson:
              '{"min_app_version":"0.1.0","maintenance":false,"message_pt":"",'
              '"consent_version":1,'
              '"tile_url":"https://t.example/{z}/{x}/{y}.png"}',
          prefs: SharedPreferences.getInstance,
          nowMs: () => 0,
        ),
      ),
      busApiProvider.overrideWith(
        (Ref ref) => BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: const TokenStore().read,
          writeToken: const TokenStore().write,
        ),
      ),
      currentNowProvider.overrideWith((Ref ref) => fixedNow),
    ],
    child: MaterialApp(theme: pontualLightTheme(), home: app),
  );
}

/// Host button that runs the flow for [line].
Widget flowButton(
  LineVM? line,
  PermissionGateway gateway, {
  Future<void> Function()? ensureNotifications,
}) {
  return wrapFlow(
    Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return FilledButton(
                onPressed: () => startShare(
                  context,
                  ref,
                  line,
                  gateway: gateway,
                  ensureNotifications: ensureNotifications ?? () async {},
                ),
                child: const Text('share'),
              );
            },
          );
        },
      ),
    ),
    gateway: gateway,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('chooser lists only sharing-capable lines', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    await tester.pumpWidget(flowButton(null, gateway));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.chooseLineTitle), findsOneWidget);
    expect(find.text('Litorâneo / Aviação'), findsOneWidget);
    expect(find.text('Guriri'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing the chooser starts nothing', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    await tester.pumpWidget(flowButton(null, gateway));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.chooseLineTitle), findsNothing);
    expect(gateway.requested, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent decline ends the flow silently', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    const LineVM line = LineVM(
      key: '60-litoraneo-aviacao',
      name: 'Litorâneo / Aviação',
      short: '60',
      supportsSharing: true,
    );
    await tester.pumpWidget(flowButton(line, gateway));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.consentTitle), findsOneWidget);
    await tester.scrollUntilVisible(find.text(UiStrings.consentDecline), 200);
    await tester.tap(find.text(UiStrings.consentDecline));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.consentTitle), findsNothing);
    expect(gateway.requested, isFalse);
    expect(await const ConsentStore().read(), isNull);
  });

  testWidgets('permission denial renders the permission card', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway()
      ..permission = LocationPermissionState.denied;
    const LineVM line = LineVM(
      key: '60-litoraneo-aviacao',
      name: 'Litorâneo / Aviação',
      short: '60',
      supportsSharing: true,
    );
    await tester.pumpWidget(flowButton(line, gateway));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.consentTitle), findsOneWidget);
    await tester.scrollUntilVisible(find.text(UiStrings.consentAccept), 200);
    await tester.tap(find.text(UiStrings.consentAccept));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.permissionPrompt), findsOneWidget);
    await tester.tap(find.text(UiStrings.permissionContinue));
    await tester.pumpAndSettle();
    // The existing share flow records the choice through its own consent
    // sheet before reaching the OS prompt; accept there too.
    final Finder recordAccept = find.text(UiStrings.consentAccept);
    expect(recordAccept, findsOneWidget);
    await tester.tap(recordAccept);
    await tester.pumpAndSettle();
    expect(find.byType(PermissionCard), findsOneWidget);
    // Title row and body share the denial copy.
    expect(find.text(UiStrings.permissionDenied), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

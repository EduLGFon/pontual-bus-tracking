// Share-flow tests: the map entry opens consent, declining stays put,
// non-pilot lines never share, failures keep the progress sheet open,
// and /trip serves the started controller or the fallback. Covers both
// the legacy shareTrip entry and the new startShare entry (which
// delegates to shareTrip). Merged into one file so the suite pays a
// single test-process startup instead of two. See PLAN.md S06 and S08.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/prefs/token_store.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/share_flow.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/design/components/permission_card.dart';
import 'package:pontual/ui/design/components/trip_dock.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:pontual/ui/features/trip/trip_flow.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/router/app_router.dart';
import 'package:pontual/ui/shell/trip_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart';

/// Bundled flags for share-flow tests. The real provider loads config.json
/// through rootBundle, whose engine channel answers only the first
/// testWidgets per file and hangs later ones; literal JSON keeps these
/// tests hermetic. See DECISIONS.md T36 test note.
const String testBundleConfig =
    '{"min_app_version":"0.1.0","maintenance":false,"message_pt":"",'
    '"consent_version":1,"tile_url":"https://t.example/{z}/{x}/{y}.png"}';

/// Pilot line for share-flow tests.
const StaticLine pilotLine = StaticLine(
  id: 60,
  code: 'litoraneo',
  short: 'LIT',
  name: 'Litoraneo',
  pilot: true,
  schedules: <Map<String, dynamic>>[],
);

/// Non-pilot line: sharing must be a no-op.
const StaticLine regularLine = StaticLine(
  id: 61,
  code: 'regular',
  short: 'REG',
  name: 'Regular',
  pilot: false,
  schedules: <Map<String, dynamic>>[],
);

/// Pumps a button that starts the share flow for [line]. Remote flags come
/// from literal JSON (see above), never from rootBundle or the network.
Widget shareButton(StaticLine line) {
  final MutableGateway gateway = MutableGateway();
  final MockClient client = MockClient((_) async {
    throw StateError('no network in share-flow tests');
  });
  return ProviderScope(
    overrides: [
      remoteConfigRepoProvider.overrideWith(
        (Ref ref) async => RemoteConfigRepository(
          client: client,
          staticBaseUrl: () => 'https://static.example',
          bundleConfigJson: testBundleConfig,
          prefs: SharedPreferences.getInstance,
          nowMs: () => 0,
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                return FilledButton(
                  // Tests never touch platform channels: notifications are
                  // a no-op here (the real request has its own unit test).
                  onPressed: () => shareTrip(
                    context,
                    ProviderScope.containerOf(context),
                    line,
                    gateway: gateway,
                    ensureNotifications: () async {},
                  ),
                  child: const Text('share'),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

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
          return FilledButton(
            onPressed: () => startShare(
              context,
              line,
              gateway: gateway,
              ensureNotifications: ensureNotifications ?? () async {},
            ),
            child: const Text('share'),
          );
        },
      ),
    ),
    gateway: gateway,
  );
}

/// Dock-like button that removes itself right after being tapped,
/// mimicking the production pill hiding under open sheets.
class _HidingDock extends StatefulWidget {
  /// Creates the hiding dock for [line].
  const _HidingDock({required this.line, required this.gateway});

  /// Line to share.
  final LineVM line;

  /// Fake OS gateway.
  final PermissionGateway gateway;

  @override
  State<_HidingDock> createState() => _HidingDockState();
}

class _HidingDockState extends State<_HidingDock> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    return FilledButton(
      onPressed: () {
        // Hide first: the captured context below is unmounted on the
        // next frame, exactly like the production dock under a sheet.
        // startShare resolves its stable context synchronously here,
        // while this element is still mounted.
        setState(() => _visible = false);
        startShare(
          context,
          widget.line,
          gateway: widget.gateway,
          ensureNotifications: () async {},
        );
      },
      child: const Text('share'),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('legacy shareTrip', () {
    testWidgets('share opens the consent sheet', (WidgetTester tester) async {
      await tester.pumpWidget(shareButton(pilotLine));
      await tester.tap(find.text('share'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhar sua localização'), findsOneWidget);
    });

    testWidgets('declining consent stays on the same screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(shareButton(pilotLine));
      await tester.tap(find.text('share'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Agora não'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhar sua localização'), findsNothing);
      expect(find.text('share'), findsOneWidget);
    });

    testWidgets('non-pilot lines never share', (WidgetTester tester) async {
      await tester.pumpWidget(shareButton(regularLine));
      await tester.tap(find.text('share'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Compartilhar sua localização'), findsNothing);
    });

    testWidgets('failed start keeps the progress sheet open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(shareButton(pilotLine));
      await tester.tap(find.text('share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Continuar'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      // The rig has no usable network or GPS: the flow must end with the
      // phased progress sheet showing the failure and a retry action,
      // never silence. Pump fixed rounds (the sheet owns a 1 s ticker,
      // so pumpAndSettle never settles).
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.text('Tentar de novo').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Iniciando viagem'), findsWidgets);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.text('Detalhes técnicos'), findsOneWidget);
    });

    testWidgets('/trip with a controller shows the trip', (
      WidgetTester tester,
    ) async {
      final Rig r = rig(happy());
      await start(r);
      final GoRouter router = buildUiRouter();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      router.go('/trip', extra: r.controller);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Compartilhando'), findsWidgets);
      // TripRoute owns the controller and disposes it with the tree.
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('/trip without a controller shows the fallback', (
      WidgetTester tester,
    ) async {
      final GoRouter router = buildUiRouter();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      router.go('/trip');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SystemScreen), findsWidgets);
      expect(find.byType(TripScreen), findsNothing);
    });
  });

  group('dock return', () {
    testWidgets('active dock opens the live trip, not the fallback', (
      WidgetTester tester,
    ) async {
      final Rig r = rig(happy());
      await start(r);
      final GoRouter router = buildUiRouter();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Attach through the mounted container: the notifier cannot take
      // state before its provider initializes.
      final BuildContext ctx = tester.element(find.byType(MaterialApp));
      ProviderScope.containerOf(
        ctx,
      ).read(tripHostProvider.notifier).attach(r.controller);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(TripDock).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The dock must carry the controller in extra: without it the
      // router renders the not-found fallback and the live trip is lost.
      expect(find.byType(TripScreen), findsWidgets);
      expect(find.byType(SystemScreen), findsNothing);
      expect(tester.takeException(), isNull);
      r.controller.dispose();
      await r.positions.close();
    });
  });

  group('startShare', () {
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
      // Single consent: the disclosure above already accepted, and the
      // share flow records through ensureConsent without a second sheet.
      expect(find.text(UiStrings.consentAccept), findsNothing);
      expect(find.byType(PermissionCard), findsOneWidget);
      // Title row and body share the denial copy.
      expect(find.text(UiStrings.permissionDenied), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('share survives the caller unmounting under sheets', (
      WidgetTester tester,
    ) async {
      // The production dock hides itself under any open sheet, unmounting
      // the context captured at tap time. The flow must continue on the
      // root navigator context instead of dying at the first mounted
      // check after the disclosure (D-U27-followup).
      final RecordingGateway gateway = RecordingGateway()
        ..permission = LocationPermissionState.denied;
      const LineVM line = LineVM(
        key: '60-litoraneo-aviacao',
        name: 'Litorâneo / Aviação',
        short: '60',
        supportsSharing: true,
      );
      await tester.pumpWidget(
        wrapFlow(
          Scaffold(
            body: _HidingDock(line: line, gateway: gateway),
          ),
          gateway: gateway,
        ),
      );
      await tester.tap(find.text('share'));
      await tester.pumpAndSettle();
      expect(find.text(UiStrings.consentTitle), findsOneWidget);
      // The dock hid itself, like the production pill under a sheet.
      expect(find.text('share'), findsNothing);
      await tester.scrollUntilVisible(find.text(UiStrings.consentAccept), 200);
      await tester.tap(find.text(UiStrings.consentAccept));
      await tester.pumpAndSettle();
      // Dead caller context or not, the pre-prompt still opens.
      expect(find.text(UiStrings.permissionPrompt), findsOneWidget);
      await tester.tap(find.text(UiStrings.permissionContinue));
      await tester.pumpAndSettle();
      expect(find.byType(PermissionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

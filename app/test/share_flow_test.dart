// Share-flow tests: the map entry opens consent, declining stays put,
// and /trip serves the started controller or the fallback. See PLAN.md
// S06 and S08.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/trip/share_flow.dart';
import 'package:pontual/ui/features/system/system_screen.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/router/app_router.dart';
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
}

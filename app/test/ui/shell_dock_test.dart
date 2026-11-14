// Shell layout tests for the trip bar. The idle floating CTA is gone from
// the shell, so content is never covered; a running trip still renders a
// bar that takes layout space above the navigation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/main.dart';
import 'package:pontual/ui/design/components/trip_dock.dart';
import 'package:pontual/ui/features/home/welcome_state.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/features/search/search_screen.dart';
import 'package:pontual/ui/shell/bottom_nav.dart';
import 'package:pontual/ui/shell/dock_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the full app with deterministic line data. Remote fetches answer
/// empty, so no test depends on the network or the asset bundle. With
/// [pendingLive] the live summary never resolves, keeping the home header
/// at its first-paint height: the shell test is about the trip bar, not
/// the live chip layout at large text scales.
Future<void> pumpApp(
  WidgetTester tester, {
  bool onboardingSeen = false,
  bool pendingLive = false,
}) {
  if (onboardingSeen) {
    SharedPreferences.setMockInitialValues(<String, Object>{
      welcomeSeenKey: true,
      coachmarkSeenKey: true,
    });
  }
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
        if (pendingLive)
          liveProvider.overrideWith((Ref ref) => Completer<LiveLines>().future),
      ],
      child: const PontualApp(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('idle shell renders no trip dock', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TripDock), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.text(UiStrings.dockIdle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active-only host keeps the idle label out of the shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LiveDockHost(showIdle: false))),
      ),
    );
    expect(find.byType(TripDock), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LiveDockHost())),
      ),
    );
    expect(find.byType(TripDock), findsOneWidget);
    expect(find.text(UiStrings.dockIdle), findsOneWidget);
  });

  testWidgets('home search stays tappable at 320x568 with 2x text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await pumpApp(tester, onboardingSeen: true, pendingLive: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SearchEntry), findsOneWidget);
    expect(find.byType(TripDock), findsNothing);
    expect(find.byType(BottomNav), findsOneWidget);

    await tester.ensureVisible(find.byType(SearchEntry));
    await tester.pump();

    await tester.tap(find.byType(SearchEntry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

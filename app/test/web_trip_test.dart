// T38 web sharing tests: visibility pause policy, screen wake fake, the
// controller hidden flag, the always-visible web banner, and the trip
// screen screen-on toggle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/screen_wake.dart';
import 'package:pontual/platform/web/visibility.dart';
import 'package:pontual/platform/web/web_banner.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart';

/// Web trip screen with an injected wake lock and clock.
Widget webTrip(Rig r, FakeScreenWake wake, {int Function()? nowMs}) {
  return ProviderScope(
    child: MaterialApp(
      theme: pontualLightTheme(),
      home: TripScreen(
        controller: r.controller,
        isWeb: true,
        nowMs: nowMs,
        screenWake: wake,
      ),
    ),
  );
}

/// Empty app that unmounts the trip screen and releases its lock.
Widget blankApp() {
  return ProviderScope(
    child: MaterialApp(theme: pontualLightTheme(), home: const SizedBox()),
  );
}

void main() {
  group('webShouldPause', () {
    test('pauses at 60 s, not before', () {
      expect(webShouldPause(59999), isFalse);
      expect(webShouldPause(60000), isTrue);
      expect(webShouldPause(120000), isTrue);
    });
  });

  group('WebVisibilityTracker', () {
    test('visible by default, never pauses', () {
      final WebVisibilityTracker tracker = WebVisibilityTracker();
      tracker.check(1000000);
      expect(tracker.paused, isFalse);
      expect(tracker.hiddenFor(1000000), 0);
    });

    test('short hide does not pause, long hide does', () {
      final WebVisibilityTracker tracker = WebVisibilityTracker();
      tracker.onHidden(0);
      tracker.check(59999);
      expect(tracker.paused, isFalse);
      tracker.check(60000);
      expect(tracker.paused, isTrue);
    });

    test('visible clears the pause', () {
      final WebVisibilityTracker tracker = WebVisibilityTracker();
      tracker.onHidden(0);
      tracker.check(90000);
      expect(tracker.paused, isTrue);
      tracker.onVisible();
      expect(tracker.paused, isFalse);
      tracker.check(200000);
      expect(tracker.paused, isFalse);
    });

    test('repeated hidden keeps the first timestamp', () {
      final WebVisibilityTracker tracker = WebVisibilityTracker();
      tracker.onHidden(1000);
      tracker.onHidden(50000);
      expect(tracker.hiddenFor(61000), 60000);
    });
  });

  group('FakeScreenWake', () {
    test('tracks enable and disable', () async {
      final FakeScreenWake lock = FakeScreenWake();
      expect(await lock.enabled, isFalse);
      await lock.enable();
      expect(await lock.enabled, isTrue);
      expect(lock.enables, 1);
      await lock.disable();
      expect(await lock.enabled, isFalse);
      expect(lock.disables, 1);
    });

    test('failEnable leaves the lock unheld', () async {
      final FakeScreenWake lock = FakeScreenWake(failEnable: true);
      await lock.enable();
      expect(await lock.enabled, isFalse);
      expect(lock.enables, 1);
    });
  });

  group('TripController web hidden', () {
    test('flag toggles and notifies, drops fixes while hidden', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Rig r = rig(happy());
      await start(r);
      expect(r.controller.isWebHidden, isFalse);
      int notified = 0;
      r.controller.addListener(() {
        notified += 1;
      });
      r.controller.setWebHidden(true);
      expect(r.controller.isWebHidden, isTrue);
      expect(notified, 1);
      r.controller.setWebHidden(true);
      expect(notified, 1);
      r.controller.setWebHidden(false);
      expect(r.controller.isWebHidden, isFalse);
      addTearDown(() async {
        await r.controller.endTrip();
        r.controller.dispose();
        await r.positions.close();
      });
    });

    test('visible recovery sends one paced ping from a fresh fix', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final FakeClock clock = FakeClock(100000);
      int pings = 0;
      int oneShots = 0;
      final MockClient client = MockClient((http.Request req) async {
        final String path = req.url.path;
        if (path == '/v1/devices') {
          return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
        }
        if (path == '/v1/consents') {
          return http.Response('{"ok":true}', 200);
        }
        if (path == '/v1/trip') {
          if (req.method == 'DELETE') {
            return http.Response('', 204);
          }
          return http.Response('{"r":"W","n":20}', 201);
        }
        if (path == '/v1/trip/ping') {
          pings += 1;
          return http.Response('{"r":"L","n":15}', 200);
        }
        return http.Response('{}', 404);
      });
      final Rig r = rig(
        client,
        clock: clock,
        oneShotPosition: (LocationSettings _) async {
          oneShots += 1;
          return pos(8, timestampMs: clock.nowMs());
        },
      );
      await start(r);
      r.controller.setWebHidden(true);
      clock.advance(61000);
      await r.controller.recoverWebSharing(hiddenForMs: 61000);
      for (int i = 0; i < 100 && pings == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(oneShots, 1);
      expect(pings, 1);
      expect(r.controller.isWebHidden, isFalse);
      expect(r.controller.endKind, isNull);
      await r.controller.endTrip();
      r.controller.dispose();
      await r.positions.close();
    });

    test('long hidden gap plus gone ends as timeout without revive', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final FakeClock clock = FakeClock(100000);
      int starts = 0;
      int pings = 0;
      final MockClient client = MockClient((http.Request req) async {
        final String path = req.url.path;
        if (path == '/v1/devices') {
          return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
        }
        if (path == '/v1/consents') {
          return http.Response('{"ok":true}', 200);
        }
        if (path == '/v1/trip') {
          if (req.method == 'DELETE') {
            return http.Response('', 204);
          }
          starts += 1;
          return http.Response('{"r":"W","n":20}', 201);
        }
        if (path == '/v1/trip/ping') {
          pings += 1;
          return http.Response('{"e":"gone"}', 404);
        }
        return http.Response('{}', 404);
      });
      final Rig r = rig(
        client,
        clock: clock,
        oneShotPosition: (LocationSettings _) async {
          return pos(8, timestampMs: clock.nowMs());
        },
      );
      await start(r);
      expect(starts, 1);
      r.controller.setWebHidden(true);
      clock.advance(600000);
      await r.controller.recoverWebSharing(hiddenForMs: 600000);
      for (int i = 0; i < 100 && r.controller.endKind == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(pings, 1);
      expect(starts, 1);
      expect(r.controller.endKind, TripEndKind.automatic);
      expect(r.controller.endDetail, 'timeout');
      r.controller.dispose();
      await r.positions.close();
    });
  });

  group('TripScreen web wake lock', () {
    testWidgets('auto-enables on start and shows the on label', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Rig r = rig(happy());
      await start(r);
      final FakeScreenWake lock = FakeScreenWake();
      await tester.pumpWidget(webTrip(r, lock));
      await tester.pump();
      expect(lock.enables, 1);
      expect(lock.held, isTrue);
      expect(find.text(UiStrings.screenOnOn), findsOneWidget);
      expect(find.text(UiStrings.screenOnOff), findsNothing);
      await tester.pumpWidget(blankApp());
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('toggle off releases the lock; resume keeps it off', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Rig r = rig(happy());
      await start(r);
      final FakeScreenWake lock = FakeScreenWake();
      await tester.pumpWidget(webTrip(r, lock));
      await tester.pump();
      expect(lock.enables, 1);

      final Finder toggle = find.byKey(const ValueKey<String>('tripScreenOn'));
      await tester.ensureVisible(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(lock.disables, 1);
      expect(lock.held, isFalse);
      expect(find.text(UiStrings.screenOnOff), findsOneWidget);
      expect(find.text(UiStrings.webWakeNote), findsNothing);
      expect(find.text(UiStrings.webWakeOffNote), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(lock.enables, 1);

      await tester.ensureVisible(toggle);
      await tester.pump();
      await tester.tap(toggle);
      await tester.pump();
      expect(lock.enables, 2);
      expect(lock.held, isTrue);
      expect(find.text(UiStrings.screenOnOn), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(lock.enables, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(blankApp());
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('failed enable turns the toggle off and captions it', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Rig r = rig(happy());
      await start(r);
      final FakeScreenWake lock = FakeScreenWake(failEnable: true);
      await tester.pumpWidget(webTrip(r, lock));
      await tester.pump();
      expect(lock.enables, 1);
      expect(find.text(UiStrings.screenOnOff), findsOneWidget);
      expect(find.text(UiStrings.screenOnUnsupported), findsOneWidget);
      expect(find.text(UiStrings.webWakeUnsupported), findsOneWidget);
      await tester.pumpWidget(blankApp());
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('releases the lock on dispose', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final Rig r = rig(happy());
      await start(r);
      final FakeScreenWake lock = FakeScreenWake();
      await tester.pumpWidget(webTrip(r, lock));
      await tester.pump();
      expect(lock.held, isTrue);
      await tester.pumpWidget(blankApp());
      await tester.pump();
      expect(lock.disables, 1);
      expect(lock.held, isFalse);
      r.controller.dispose();
      await r.positions.close();
    });

    testWidgets('reacquires the wake lock and requests a fresh fix', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final FakeClock clock = FakeClock(100000);
      final FakeScreenWake lock = FakeScreenWake();
      int oneShots = 0;
      final Rig r = rig(
        happy(),
        clock: clock,
        oneShotPosition: (LocationSettings _) async {
          oneShots += 1;
          return pos(8, timestampMs: clock.nowMs());
        },
      );
      await start(r);
      await tester.pumpWidget(webTrip(r, lock, nowMs: clock.nowMs));
      await tester.pump();
      final int enablesBefore = lock.enables;
      final int shotsBefore = oneShots;
      expect(enablesBefore, greaterThanOrEqualTo(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(61000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (int i = 0; i < 100 && oneShots == shotsBefore; i++) {
        await tester.pump();
      }
      expect(lock.enables, enablesBefore + 1);
      expect(oneShots, shotsBefore + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(blankApp());
      r.controller.dispose();
      await r.positions.close();
    });
  });

  group('WebTripBanner', () {
    testWidgets('shows the keep-open text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebTripBanner())),
      );
      expect(find.textContaining('Mantenha esta tela aberta'), findsOneWidget);
      expect(find.textContaining('brilho'), findsOneWidget);
    });

    testWidgets('paused and unsupported lines appear on demand', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebTripBanner(paused: true, wakeUnsupported: true),
          ),
        ),
      );
      expect(find.textContaining('Tela oculta'), findsOneWidget);
      expect(find.textContaining('não mantém a tela ligada'), findsOneWidget);
    });

    testWidgets('off toggle no longer claims the screen stays on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebTripBanner(screenOn: false))),
      );
      expect(find.text(UiStrings.webWakeOffNote), findsOneWidget);
      expect(find.text(UiStrings.webWakeNote), findsNothing);
      expect(find.textContaining('página visível'), findsOneWidget);
    });
  });

  group('keep-awake copy', () {
    test('Android says the screen can be off and locked', () {
      expect(UiStrings.keepAwakeTip, contains('desligar a tela'));
      expect(UiStrings.keepAwakeTip, contains('bloquear o celular'));
      expect(UiStrings.keepAwakeTip, contains('notificação'));
    });

    test('web keeps the tab visible and mentions the screen lock', () {
      expect(UiStrings.keepAwakeTipWeb, contains('aba aberta'));
      expect(UiStrings.keepAwakeTipWeb, contains('visível'));
      expect(UiStrings.keepAwakeTipWeb, contains('tela sempre ligada'));
    });
  });
}

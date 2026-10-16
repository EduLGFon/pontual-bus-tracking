// T33 tests: controller solo ride on fakes plus end-card copy.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/trip/trip_end_card.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGateway implements PermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.granted;

  @override
  Future<bool> servicesOn() async => true;

  @override
  Future<bool> preciseAccuracy() async => true;

  @override
  Future<void> openSettings() async {}
}

/// Gateway that grants approximate-only location, for the D67 path.
class _ImpreciseGateway extends FakeGateway {
  @override
  Future<bool> preciseAccuracy() async => false;
}

/// Gateway that always denies permission, for the denial path test.
class _DeniedGateway implements PermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.denied;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.denied;

  @override
  Future<bool> servicesOn() async => true;

  @override
  Future<bool> preciseAccuracy() async => true;

  @override
  Future<void> openSettings() async {}
}

Position pos(
  double lat,
  double lng, {
  int timestampMs = 100000,
  double accuracyM = 10,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
    accuracy: accuracyM,
    altitude: 0,
    heading: 90,
    speed: 8,
    speedAccuracy: 1,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
}

TripController controller(
  MockClient client, {
  bool feed = true,
  PermissionGateway? gateway,
}) {
  String? token;
  // ignore: close_sinks - single buffered test event; the service owns it.
  final StreamController<Position> positions = StreamController<Position>();
  final TripController controller = TripController(
    TripDeps(
      api: BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => token,
        writeToken: (String t) async => token = t,
      ),
      gateway: gateway ?? FakeGateway(),
      consentStore: const ConsentStore(),
      consentVersion: 1,
      locations: () => LocationService(
        positionStream: (_) => positions.stream,
        batteryLevel: () async => 80,
        charging: () async => false,
        nowMs: () => 100000,
      ),
      clock: FakeClock(100000),
    ),
  );
  if (feed) {
    // Feed one fix on the next microtask so starts observe it.
    scheduleMicrotask(() {
      positions.add(pos(-18.72, -39.85));
    });
  }
  return controller;
}

MockClient happy() {
  return MockClient((http.Request req) async {
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
      return http.Response('{"r":"L","n":15}', 200);
    }
    return http.Response('{}', 404);
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('solo ride: consent to active to user end', () async {
    final TripController c = controller(happy());
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isTrue);
    for (int i = 0; i < 50 && c.state is! TripActive; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.state, isA<TripActive>());
    await c.endTrip();
    expect(c.state, isA<TripIdle>());
    expect(c.endKind, TripEndKind.user);
    c.dispose();
  });

  test('no fix within the timeout reports noGps', () async {
    final TripController c = controller(happy(), feed: false);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
      firstFixTimeout: const Duration(milliseconds: 50),
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.noGps);
    expect(c.state, isA<TripIdle>());
    c.dispose();
  });

  test(
    'start anchors on the first good fix, not the first coarse one',
    () async {
      final FakeClock clock = FakeClock(100000);
      // ignore: close_sinks - closed at the end of the test.
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      String? lastStartBody;
      String? token;
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
          lastStartBody = req.body;
          return http.Response('{"r":"W","n":20}', 201);
        }
        if (path == '/v1/trip/ping') {
          return http.Response('{"r":"L","n":15}', 200);
        }
        return http.Response('{}', 404);
      });
      final TripController c = TripController(
        TripDeps(
          api: BusApi(
            client: client,
            baseUrl: () => 'http://127.0.0.1:8080',
            readToken: () async => token,
            writeToken: (String t) async => token = t,
          ),
          gateway: FakeGateway(),
          consentStore: const ConsentStore(),
          consentVersion: 1,
          locations: () => LocationService(
            positionStream: (_) => positions.stream,
            batteryLevel: () async => 80,
            charging: () async => false,
            nowMs: () => clock.nowMs(),
          ),
          clock: clock,
        ),
      );
      bool? started;
      unawaited(
        c
            .startTrip(
              lineId: 7,
              lineLabel: '7',
              showConsent: () async => true,
              showPermissions: () async {},
            )
            .then((bool v) => started = v),
      );
      // Coarse fixes keep the start waiting: nothing is published yet.
      for (int i = 0; i < 20; i++) {
        positions.add(
          pos(-18.70, -39.85, timestampMs: clock.nowMs(), accuracyM: 50),
        );
        await Future<void>.microtask(() {});
      }
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(started, isNull);
      expect(lastStartBody, isNull);
      // The first good fix anchors the trip.
      for (int i = 0; i < 100 && started == null; i++) {
        positions.add(
          pos(-18.72, -39.85, timestampMs: clock.nowMs(), accuracyM: 10),
        );
        await Future<void>.microtask(() {});
      }
      expect(started, isTrue);
      expect(lastStartBody, contains('"lat":-18.72'));
      c.dispose();
      await positions.close();
    },
  );

  test(
    'start falls back to the best-seen fix when no good fix arrives',
    () async {
      final FakeClock clock = FakeClock(100000);
      // ignore: close_sinks - closed at the end of the test.
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      String? lastStartBody;
      String? token;
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
          lastStartBody = req.body;
          return http.Response('{"r":"W","n":20}', 201);
        }
        if (path == '/v1/trip/ping') {
          return http.Response('{"r":"L","n":15}', 200);
        }
        return http.Response('{}', 404);
      });
      final TripController c = TripController(
        TripDeps(
          api: BusApi(
            client: client,
            baseUrl: () => 'http://127.0.0.1:8080',
            readToken: () async => token,
            writeToken: (String t) async => token = t,
          ),
          gateway: FakeGateway(),
          consentStore: const ConsentStore(),
          consentVersion: 1,
          locations: () => LocationService(
            positionStream: (_) => positions.stream,
            batteryLevel: () async => 80,
            charging: () async => false,
            nowMs: () => clock.nowMs(),
          ),
          clock: clock,
        ),
      );
      bool? started;
      unawaited(
        c
            .startTrip(
              lineId: 7,
              lineLabel: '7',
              showConsent: () async => true,
              showPermissions: () async {},
              firstFixTimeout: const Duration(milliseconds: 100),
            )
            .then((bool v) => started = v),
      );
      // Only coarse fixes inside the window: the start uses the best one.
      // Keep feeding while waiting: the 100 ms window is real time, and
      // fixes sent before the service subscribes are lost on broadcast.
      // After feeding stops, one last window elapses before the fallback
      // fires, so the test waits past it.
      for (int i = 0; i < 10; i++) {
        positions.add(
          pos(
            i.isEven ? -18.70 : -18.71,
            -39.85,
            timestampMs: clock.nowMs(),
            accuracyM: i.isEven ? 50 : 45,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      for (int i = 0; i < 30 && started == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(started, isTrue);
      expect(lastStartBody, contains('"lat":-18.71'));
      c.dispose();
      await positions.close();
    },
  );

  test(
    'approximate-only grant reports imprecise before any trip call',
    () async {
      int starts = 0;
      final MockClient client = MockClient((http.Request req) async {
        final String path = req.url.path;
        if (path == '/v1/devices') {
          return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
        }
        if (path == '/v1/consents') {
          return http.Response('{"ok":true}', 200);
        }
        if (path == '/v1/trip') {
          starts += 1;
          return http.Response('{"r":"W","n":20}', 201);
        }
        return http.Response('{}', 404);
      });
      final TripController c = controller(client, gateway: _ImpreciseGateway());
      final bool started = await c.startTrip(
        lineId: 7,
        lineLabel: '7',
        showConsent: () async => true,
        showPermissions: () async {},
      );
      expect(started, isFalse);
      expect(c.failReason, StartFailure.imprecise);
      expect(c.state, isA<TripIdle>());
      expect(starts, 0);
      c.dispose();
    },
  );

  test('registration failure reports offline', () async {
    final MockClient client = MockClient((http.Request req) async {
      throw http.ClientException('unreachable');
    });
    final TripController c = controller(client);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.offline);
    expect(c.state, isA<TripIdle>());
    c.dispose();
  });

  test('registration server error reports failed', () async {
    final MockClient client = MockClient((http.Request req) async {
      if (req.url.path == '/v1/devices') {
        return http.Response('{}', 500);
      }
      return http.Response('{}', 404);
    });
    final TripController c = controller(client);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.failed);
    expect(c.state, isA<TripIdle>());
    c.dispose();
  });

  test('rate-limited start reports busy', () async {
    final MockClient client = MockClient((http.Request req) async {
      final String path = req.url.path;
      if (path == '/v1/devices') {
        return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
      }
      if (path == '/v1/consents') {
        return http.Response('{"ok":true}', 200);
      }
      if (path == '/v1/trip') {
        return http.Response('{"e":"rate"}', 429);
      }
      return http.Response('{}', 404);
    });
    final TripController c = controller(client);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.busy);
    c.dispose();
  });

  test('consent rejection clears the posted flag for a repost', () async {
    final MockClient client = MockClient((http.Request req) async {
      final String path = req.url.path;
      if (path == '/v1/devices') {
        return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
      }
      if (path == '/v1/consents') {
        return http.Response('{"ok":true}', 200);
      }
      if (path == '/v1/trip') {
        return http.Response('{"e":"consent"}', 403);
      }
      return http.Response('{}', 404);
    });
    final TripController c = controller(client);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.failed);
    expect(await const ConsentStore().readPosted(), isNull);
    c.dispose();
  });

  test('denied permission reports permission', () async {
    final TripController c = controller(happy(), gateway: _DeniedGateway());
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(c.failReason, StartFailure.permission);
    c.dispose();
  });

  test('declined consent never touches the network', () async {
    int calls = 0;
    final MockClient client = MockClient((_) async {
      calls += 1;
      return http.Response('', 500);
    });
    final TripController c = controller(client);
    final bool started = await c.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => false,
      showPermissions: () async {},
    );
    expect(started, isFalse);
    expect(calls, 0);
    expect(c.state, isA<TripIdle>());
    c.dispose();
  });

  testWidgets('trip screen shows sharing state', (WidgetTester tester) async {
    final TripController c = controller(happy());
    // Kick off without awaiting: each async hop needs pump rounds to flush
    // the fix stream the start is waiting for.
    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: TripScreen(controller: c)),
      ),
    );
    for (int i = 0; i < 30 && started == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(started, isTrue);
    expect(find.textContaining('Compartilhando'), findsWidgets);
    await c.endTrip();
    await tester.pump(const Duration(milliseconds: 100));
    c.dispose();
  });

  test('pings are paced to the server interval', () async {
    String? token;
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
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
        return http.Response('{"r":"W","n":20}', 201);
      }
      if (path == '/v1/trip/ping') {
        pings += 1;
        return http.Response('{"r":"L","n":15}', 200);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );
    Future<void> flush() async {
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      positions.add(pos(-18.72, -39.85));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    // Start (n:20) arms the next slot 20 s out: an immediate fix is
    // tracked for health but sends nothing.
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    expect(pings, 0);
    // At the slot the latest fix goes out exactly once.
    clock.advance(20000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    expect(pings, 1);
    // The ping answer (n:15) re-arms the slot; early fixes wait.
    clock.advance(14000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    expect(pings, 1);
    clock.advance(1000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    expect(pings, 2);
    c.dispose();
    await positions.close();
  });

  test('forcePingNow sends immediately past the pacing slot', () async {
    String? token;
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
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
        return http.Response('{"r":"W","n":20}', 201);
      }
      if (path == '/v1/trip/ping') {
        pings += 1;
        return http.Response('{"r":"L","n":15}', 200);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );
    Future<void> flush() async {
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      positions.add(pos(-18.72, -39.85));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    // Start (n:20) arms the next slot 20 s out: nothing sent yet. One more
    // fix flows through the run loop (tracked for health, pacing-skipped)
    // so there is a latest fix to force out.
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    expect(pings, 0);
    // The test button bypasses the slot and sends the latest fix at once.
    expect(c.forcePingNow(), isTrue);
    await flush();
    expect(pings, 1);
    c.dispose();
    await positions.close();
  });

  test('forcePingNow is false with no trip running', () async {
    final TripController c = controller(happy(), feed: false);
    expect(c.forcePingNow(), isFalse);
    c.dispose();
  });

  test('late outcome from a previous trip is ignored', () async {
    final Completer<http.Response> hanging = Completer<http.Response>();
    String? token;
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int starts = 0;
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
        // The first trip sends immediately (n:0) so its ping hangs in
        // flight; the second trip is paced (n:3600) so it sends nothing
        // and only the stale outcome arrives. That isolates the
        // generation guard: any end must come from the stale outcome.
        return http.Response(
          starts == 1 ? '{"r":"W","n":0}' : '{"r":"W","n":3600}',
          201,
        );
      }
      if (path == '/v1/trip/ping') {
        return hanging.future;
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );
    Future<bool> begin() async {
      bool? started;
      unawaited(
        c
            .startTrip(
              lineId: 7,
              lineLabel: '7',
              showConsent: () async => true,
              showPermissions: () async {},
            )
            .then((bool v) => started = v),
      );
      for (int i = 0; i < 100 && started == null; i++) {
        positions.add(pos(-18.72, -39.85));
        await Future<void>.microtask(() {});
      }
      expect(started, isTrue);
      return true;
    }

    await begin();
    // First trip sends one ping and stalls in flight (n:0 slots every
    // fix immediately, so no clock advance is needed).
    positions.add(pos(-18.72, -39.85));
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await c.endTrip();
    expect(c.state, isA<TripIdle>());
    // Second trip on the same controller, then the stale first-trip
    // outcome (even an abuse end) must not touch it.
    await begin();
    hanging.complete(http.Response('{"r":"W","n":20,"e":"abuse"}', 200));
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.state, isA<TripActive>());
    expect(c.endKind, isNull);
    c.dispose();
    await positions.close();
  });

  test('a spurious gone revives the trip once', () async {
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int starts = 0;
    int pings = 0;
    bool deadOnce = true;
    String? lastStartBody;
    String? token;
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
        lastStartBody = req.body;
        return http.Response('{"r":"W","n":20}', 201);
      }
      if (path == '/v1/trip/ping') {
        pings += 1;
        if (deadOnce) {
          deadOnce = false;
          return http.Response('{"e":"gone"}', 404);
        }
        return http.Response('{"r":"L","n":15}', 200);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );
    Future<void> flush() async {
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    expect(starts, 1);
    // First ping slot 404s: the trip revives instead of ending.
    clock.advance(20000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    await flush();
    for (int i = 0; i < 100 && starts < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(starts, 2);
    expect(lastStartBody, contains('"resume":true'));
    expect(pings, 1);
    expect(c.state, isA<TripActive>());
    expect(c.endKind, isNull);
    c.dispose();
    await positions.close();
  });

  test('a persistent gone ends the trip after one revive', () async {
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int starts = 0;
    String? token;
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
        return http.Response('{"e":"gone"}', 404);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    // First 404 revives (second start); the next one ends the trip, and
    // no third start ever fires: the revive never loops.
    clock.advance(20000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    for (int i = 0; i < 100 && starts < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(starts, 2);
    expect(c.state, isA<TripActive>());
    clock.advance(20000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    for (int i = 0; i < 100 && c.endKind == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(starts, 2);
    expect(c.state, isA<TripIdle>());
    expect(c.endKind, TripEndKind.server);
    c.dispose();
    await positions.close();
  });

  test('cancel during the create POST ends the orphan record', () async {
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    final Completer<http.Response> hangingStart = Completer<http.Response>();
    bool postSeen = false;
    int deletes = 0;
    String? token;
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
          deletes += 1;
          return http.Response('', 204);
        }
        postSeen = true;
        return hangingStart.future;
      }
      if (path == '/v1/trip/ping') {
        return http.Response('{"r":"L","n":15}', 200);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    // Feed fixes until the create POST is in flight, then cancel under it.
    for (int i = 0; i < 100 && !postSeen; i++) {
      positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
      await Future<void>.microtask(() {});
    }
    expect(postSeen, isTrue);
    c.cancelStart();
    hangingStart.complete(http.Response('{"r":"W","n":20}', 201));
    for (int i = 0; i < 100 && started == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // No zombie trip: the start reports cancelled and the orphan server
    // record is ended best-effort instead of lingering unpublished.
    expect(started, isFalse);
    expect(c.failReason, StartFailure.declined);
    expect(c.state, isA<TripIdle>());
    expect(deletes, 1);
    c.dispose();
    await positions.close();
  });

  test('a dead token ends the trip instead of hanging offline', () async {
    final FakeClock clock = FakeClock(100000);
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    String? token;
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
        return http.Response('{"e":"auth"}', 401);
      }
      return http.Response('{}', 404);
    });
    final TripController c = TripController(
      TripDeps(
        api: BusApi(
          client: client,
          baseUrl: () => 'http://127.0.0.1:8080',
          readToken: () async => token,
          writeToken: (String t) async => token = t,
        ),
        gateway: FakeGateway(),
        consentStore: const ConsentStore(),
        consentVersion: 1,
        locations: () => LocationService(
          positionStream: (_) => positions.stream,
          batteryLevel: () async => 80,
          charging: () async => false,
          nowMs: () => clock.nowMs(),
        ),
        clock: clock,
      ),
    );

    bool? started;
    unawaited(
      c
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    // The 401 refreshes once, retries, and still 401s: the trip ends
    // instead of retrying with backoff forever.
    clock.advance(20000);
    positions.add(pos(-18.72, -39.85, timestampMs: clock.nowMs()));
    for (int i = 0; i < 100 && c.endKind == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.state, isA<TripIdle>());
    expect(c.endKind, TripEndKind.server);
    c.dispose();
    await positions.close();
  });

  test('confirming after dispose does not throw', () {
    final TripController c = controller(happy(), feed: false);
    c.dispose();
    c.confirmStillRiding();
  });

  testWidgets('end cards carry each reason', (WidgetTester tester) async {
    Future<void> pumpCard(TripEndKind kind, String? detail) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: pontualLightTheme(),
            home: Scaffold(
              body: TripEndCard(kind: kind, detail: detail),
            ),
          ),
        ),
      );
    }

    await pumpCard(TripEndKind.automatic, 'idle');
    expect(find.textContaining('parado por 10 minutos'), findsOneWidget);

    await pumpCard(TripEndKind.abuse, null);
    expect(find.textContaining('inconsistentes'), findsOneWidget);

    await pumpCard(TripEndKind.user, null);
    expect(find.text(UiStrings.endDone), findsOneWidget);
    // Unmount to cancel the auto-dismiss timer before teardown.
    await tester.pumpWidget(Container());
  });
}

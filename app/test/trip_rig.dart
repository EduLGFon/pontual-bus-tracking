// Shared rig for trip controller and trip screen tests: mutable
// permission gateway, broadcast positions, controller builder with a fake
// clock, happy-path HTTP doubles, and a start helper that feeds fixes
// until the trip observes one. Not a test file itself.
import 'dart:async';

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
import 'package:pontual/platform/android/gnss_quality.dart';

/// Controllable permission gateway for trip tests.
class MutableGateway implements PermissionGateway {
  /// Current permission answer.
  LocationPermissionState permission = LocationPermissionState.granted;

  /// Location services answer.
  bool services = true;

  /// Precise-accuracy answer. False models an approximate-only grant.
  bool precise = true;

  @override
  Future<LocationPermissionState> check() async => permission;

  @override
  Future<LocationPermissionState> request() async => permission;

  @override
  Future<bool> servicesOn() async => services;

  @override
  Future<bool> preciseAccuracy() async => precise;

  @override
  Future<void> openSettings() async {}
}

/// One raw position at [speed] m/s inside the accepted area. Pass the
/// fake [timestampMs] when the test advances its clock past the 20 s
/// freshness window, or the stale filter correctly drops the fix.
Position pos(double speed, {int timestampMs = 100000, double accuracyM = 10}) {
  return Position(
    latitude: -18.72,
    longitude: -39.85,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
    accuracy: accuracyM,
    altitude: 0,
    heading: 90,
    speed: speed,
    speedAccuracy: 1,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
}

/// One accepted fix at [speed] m/s.
TripFix fix(double speed) {
  return TripFix(
    seq: 1,
    lat: -18.72,
    lng: -39.85,
    speedMps: speed,
    heading: null,
    accuracyM: 10,
    batteryPct: 80,
    charging: false,
  );
}

/// Controller under test with its clock, gateway, and positions.
class Rig {
  /// Creates a rig.
  Rig(this.controller, this.clock, this.gateway, this.positions);

  /// Controller under test.
  final TripController controller;

  /// Fake clock driving the controller.
  final FakeClock clock;

  /// Controllable permission gateway.
  final MutableGateway gateway;

  /// Broadcast positions: mode switches re-subscribe, mirroring the
  /// geolocator factory which returns a fresh stream per mode.
  final StreamController<Position> positions;
}

/// Builds a rig answering HTTP with [client].
Rig rig(
  MockClient client, {
  MutableGateway? gateway,
  FakeClock? clock,
  GnssQualityReader? gnssReader,
}) {
  String? token;
  final MutableGateway gw = gateway ?? MutableGateway();
  final FakeClock clk = clock ?? FakeClock(100000);
  // ignore: close_sinks - closed at the end of each test.
  final StreamController<Position> positions =
      StreamController<Position>.broadcast();
  final TripController controller = TripController(
    TripDeps(
      api: BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => token,
        writeToken: (String t) async => token = t,
      ),
      gateway: gw,
      consentStore: const ConsentStore(),
      consentVersion: 1,
      locations: () => LocationService(
        positionStream: (_) => positions.stream,
        batteryLevel: () async => 80,
        charging: () async => false,
        nowMs: () => 100000,
      ),
      clock: clk,
      gnssReader: gnssReader,
    ),
  );
  return Rig(controller, clk, gw, positions);
}

/// HTTP double where every trip call succeeds.
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

/// Starts a trip on the rig, feeding fixes until the start observes one.
Future<void> start(Rig r) async {
  bool? started;
  unawaited(
    r.controller
        .startTrip(
          lineId: 7,
          lineLabel: '7',
          showConsent: () async => true,
          showPermissions: () async {},
        )
        .then((bool v) => started = v),
  );
  // The start waits for the first accepted fix. Broadcast drops events
  // sent before the service subscribes, so keep offering fixes until
  // the start observes one. Microtask yield (not a delayed future) so the
  // helper works both in real async and in FakeAsync widget tests, where
  // timers never fire without pumped time.
  for (int i = 0; i < 100 && started == null; i++) {
    r.positions.add(pos(8));
    await Future<void>.microtask(() {});
  }
  expect(started, isTrue);
  for (int i = 0; i < 50 && r.controller.state is! TripActive; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(r.controller.state, isA<TripActive>());
}

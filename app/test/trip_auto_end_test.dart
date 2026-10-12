// T34 tests: auto-end, RF16 walking prompt, offline saver, GPS-off and
// permission-revoked handling on the controller. See PLAN.md 8.6, 11.3,
// S08, and RF16.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/domain/trip/auto_end.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/features/trip/trip_end_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('walking prompt appears after 4 min slow', () async {
    final Rig r = rig(happy());
    await start(r);
    r.controller.onFixForTest(fix(0));
    r.clock.advance(walkingPromptAfterMs + 1000);
    r.controller.onFixForTest(fix(0));
    expect(r.controller.walkingPromptVisible, isTrue);
    r.controller.dispose();
    await r.positions.close();
  });

  test('walking timeout without answer ends the trip', () async {
    final Rig r = rig(happy());
    await start(r);
    r.controller.onFixForTest(fix(0));
    r.clock.advance(walkingPromptAfterMs + 1000);
    r.controller.onFixForTest(fix(0));
    r.clock.advance(walkingTimeoutMs + 1000);
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripIdle>());
    expect(r.controller.endKind, TripEndKind.automatic);
    expect(r.controller.endDetail, 'walking');
    expect(
      const TripEndCard(kind: TripEndKind.automatic, detail: 'walking').message,
      contains('parecia que'),
    );
    r.controller.dispose();
    await r.positions.close();
  });

  test('confirming still riding clears the prompt', () async {
    final Rig r = rig(happy());
    await start(r);
    r.controller.onFixForTest(fix(0));
    r.clock.advance(walkingPromptAfterMs + 1000);
    r.controller.onFixForTest(fix(0));
    expect(r.controller.walkingPromptVisible, isTrue);
    r.controller.confirmStillRiding();
    expect(r.controller.walkingPromptVisible, isFalse);
    r.clock.advance(walkingTimeoutMs + 1000);
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripActive>());
    r.controller.dispose();
    await r.positions.close();
  });

  test('gps off pauses first and ends after 5 min', () async {
    final Rig r = rig(happy());
    await start(r);
    r.gateway.services = false;
    await r.controller.checkAutoEndForTest();
    expect(r.controller.isPaused, isTrue);
    expect(r.controller.state, isA<TripActive>());
    r.clock.advance(gpsOffAfterMs + 1000);
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripIdle>());
    expect(r.controller.endKind, TripEndKind.permission);
    expect(r.controller.endDetail, 'gps');
    expect(
      const TripEndCard(kind: TripEndKind.permission, detail: 'gps').message,
      contains('desligada'),
    );
    r.controller.dispose();
    await r.positions.close();
  });

  test('permission revoked ends the trip after consecutive polls', () async {
    final Rig r = rig(happy());
    await start(r);
    r.gateway.permission = LocationPermissionState.denied;
    // One or two flapping polls must not end a healthy trip (D29).
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripActive>());
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripActive>());
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripIdle>());
    expect(r.controller.endKind, TripEndKind.permission);
    r.controller.dispose();
    await r.positions.close();
  });

  test('max duration still ends the trip', () async {
    final Rig r = rig(happy());
    await start(r);
    r.clock.advance(tripMaxMs + 1000);
    await r.controller.checkAutoEndForTest();
    expect(r.controller.state, isA<TripIdle>());
    expect(r.controller.endKind, TripEndKind.automatic);
    r.controller.dispose();
    await r.positions.close();
  });

  test('120 s without success enters offline saver, success heals', () async {
    final Completer<http.Response> hanging = Completer<http.Response>();
    final MockClient client = MockClient((http.Request req) async {
      final String path = req.url.path;
      if (path == '/v1/devices') {
        return http.Response('{"token":"bm1_t","exp":1,"id":"d"}', 201);
      }
      if (path == '/v1/consents') {
        return http.Response('{"ok":true}', 200);
      }
      if (path == '/v1/trip' && req.method == 'POST') {
        return http.Response('{"r":"W","n":20}', 201);
      }
      if (path == '/v1/trip/ping') {
        return hanging.future;
      }
      return http.Response('', 204);
    });
    final Rig r = rig(client);
    await start(r);
    r.positions.add(pos(8));
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    r.clock.advance(121 * 1000);
    await r.controller.checkAutoEndForTest();
    expect(r.controller.isOffline, isTrue);
    expect(activeRole(r.controller.state), TripRole.offlineSaver);
    hanging.complete(http.Response('{"r":"F","n":90}', 200));
    // Paced sends mean no ping is in flight: the next fresh fix sends
    // (its slot is long past) and that success heals the trip.
    r.positions.add(pos(8, timestampMs: r.clock.nowMs()));
    for (int i = 0; i < 50 && r.controller.isOffline; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(r.controller.isOffline, isFalse);
    expect(activeRole(r.controller.state), TripRole.follower);
    r.controller.dispose();
    await r.positions.close();
  });
}

// Deterministic tests for the 5 s ping scheduler (PLAN.md 8.7).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart' as rig;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  test('steady 5 s sends are 5 s apart', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
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
        return http.Response('{"r":"W","n":5}', 201);
      }
      if (path == '/v1/trip/ping') {
        starts.add(r.clock.nowMs());
        return http.Response('{"r":"W","n":5}', 200);
      }
      return http.Response('{}', 404);
    });
    r = rig.rig(client);
    await rig.start(r);

    for (int i = 0; i < 4; i++) {
      r.clock.advance(5000);
      r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, greaterThanOrEqualTo(3));
    for (int i = 1; i < starts.length; i++) {
      final int gap = starts[i] - starts[i - 1];
      expect(gap, greaterThanOrEqualTo(4500));
      expect(gap, lessThanOrEqualTo(5300));
    }
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('fix arriving just before slot is held and sent at slot', () async {
    final List<int> starts = <int>[];
    final List<int> seqs = <int>[];
    late rig.Rig r;
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
        return http.Response('{"r":"W","n":5}', 201);
      }
      if (path == '/v1/trip/ping') {
        starts.add(r.clock.nowMs());
        seqs.add(
          int.parse(RegExp(r'"seq":(\d+)').firstMatch(req.body)!.group(1)!),
        );
        return http.Response('{"r":"W","n":5}', 200);
      }
      return http.Response('{}', 404);
    });
    r = rig.rig(client);
    await rig.start(r);

    r.clock.advance(4500);
    r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
    await Future<void>.delayed(Duration.zero);
    r.clock.advance(500);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, 1);
    expect(seqs.last, r.locations.debugSeq);
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('fix during slow in-flight request waits for next slot', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
    final Completer<http.Response> gate = Completer<http.Response>();
    bool firstPing = true;
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
        return http.Response('{"r":"W","n":5}', 201);
      }
      if (path == '/v1/trip/ping') {
        if (firstPing) {
          firstPing = false;
          starts.add(r.clock.nowMs());
          return gate.future;
        }
        starts.add(r.clock.nowMs());
        return http.Response('{"r":"W","n":5}', 200);
      }
      return http.Response('{}', 404);
    });
    r = rig.rig(client);
    await rig.start(r);

    r.clock.advance(5000);
    r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, 1);

    r.clock.advance(1000);
    r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, 1);

    gate.complete(http.Response('{"r":"W","n":5}', 200));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, 1);

    r.clock.advance(4000);
    r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(starts.length, 2);
    expect(starts[1] - starts[0], greaterThanOrEqualTo(5000));
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('server interval change n=10 is honored', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
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
        return http.Response('{"r":"W","n":10}', 201);
      }
      if (path == '/v1/trip/ping') {
        starts.add(r.clock.nowMs());
        return http.Response('{"r":"W","n":10}', 200);
      }
      return http.Response('{}', 404);
    });
    r = rig.rig(client);
    await rig.start(r);

    for (int i = 0; i < 2; i++) {
      r.clock.advance(10000);
      r.positions.add(rig.pos(8, timestampMs: r.clock.nowMs()));
      await Future<void>.delayed(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
    expect(starts.length, greaterThanOrEqualTo(2));
    for (int i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], greaterThanOrEqualTo(9500));
      expect(starts[i] - starts[i - 1], lessThanOrEqualTo(10500));
    }
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('ending trip cancels timer, no further requests', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
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
        return http.Response('{"r":"W","n":5}', 201);
      }
      if (path == '/v1/trip/ping') {
        starts.add(r.clock.nowMs());
        return http.Response('{"r":"W","n":5}', 200);
      }
      return http.Response('{}', 404);
    });
    r = rig.rig(client);
    await rig.start(r);
    final int before = starts.length;
    await r.controller.endTrip();
    await Future<void>.delayed(Duration.zero);
    r.clock.advance(10000);
    await Future<void>.delayed(const Duration(seconds: 10));
    expect(starts.length, before);
    r.controller.dispose();
    await r.positions.close();
  });
}

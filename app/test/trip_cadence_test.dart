// Deterministic tests for the 5 s ping scheduler (PLAN.md 8.7).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:pontual/core/time/clock.dart';

import 'trip_rig.dart' as rig;

class _ManualTimer implements Timer {
  _ManualTimer(this.dueMs, this._callback);

  int dueMs;
  final void Function() _callback;

  bool _cancelled = false;
  bool _fired = false;
  @override
  int get tick => 0;

  @override
  bool get isActive => !_cancelled && !_fired;

  @override
  void cancel() {
    _cancelled = true;
  }

  void fire() {
    if (_cancelled || _fired) {
      return;
    }
    _fired = true;
    _callback();
  }
}

class _TimerHarness {
  _TimerHarness(this.clock);

  final FakeClock clock;
  final List<_ManualTimer> _timers = <_ManualTimer>[];

  Timer createTimer(Duration duration, void Function() callback) {
    final _ManualTimer t = _ManualTimer(
      clock.nowMs() + duration.inMilliseconds,
      callback,
      );
    _timers.add(t);
    return t;
  }

  void fireDue() {
    bool progress = true;
    while (progress) {
      progress = false;
      final List<_ManualTimer> due = _timers
          .where(
            (_ManualTimer t) =>
                !t._cancelled && !t._fired && t.dueMs <= clock.nowMs(),
          )
          .toList();
      for (final _ManualTimer t in due) {
        t.fire();
        progress = true;
      }
    }
  }
}

Future<void> _flush() async {
  for (int i = 0; i < 50; i++) {
    await Future<void>.microtask(() {});
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('steady 5 s sends are 5 s apart', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
    final FakeClock clock = FakeClock(100000);
    final _TimerHarness harness = _TimerHarness(clock);
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
    r = rig.rig(client, clock: clock, createTimer: harness.createTimer);
    await rig.start(r);

    for (int i = 0; i < 4; i++) {
      clock.advance(5000);
      r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
      await _flush();
      harness.fireDue();
      await _flush();
    }
    expect(starts.length, greaterThanOrEqualTo(3));
    for (int i = 1; i < starts.length; i++) {
      final int gap = starts[i] - starts[i - 1];
      expect(gap, greaterThanOrEqualTo(5000));
      expect(gap, lessThanOrEqualTo(5050));
    }
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('fix arriving just before slot is held and sent at slot', () async {
    final List<int> starts = <int>[];
    final List<int> seqs = <int>[];
    late rig.Rig r;
    final FakeClock clock = FakeClock(100000);
    final _TimerHarness harness = _TimerHarness(clock);
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
    r = rig.rig(client, clock: clock, createTimer: harness.createTimer);
    await rig.start(r);

    clock.advance(4500);
    r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
    await _flush();
    clock.advance(500);
    r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
    await _flush();
    harness.fireDue();
    await _flush();
    expect(starts.length, 1);
    expect(seqs.last, r.locations.debugSeq);
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('fix during slow in-flight request waits for next slot', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
    final FakeClock clock = FakeClock(100000);
    final _TimerHarness harness = _TimerHarness(clock);
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
    r = rig.rig(client, clock: clock, createTimer: harness.createTimer);
    await rig.start(r);

    clock.advance(5000);
    r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
    await _flush();
    harness.fireDue();
    await _flush();
    expect(starts.length, 1);

    clock.advance(1000);
    r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
    await _flush();
    harness.fireDue();
    await _flush();
    expect(starts.length, 1);

    gate.complete(http.Response('{"r":"W","n":5}', 200));
    await _flush();
    expect(starts.length, 1);

    clock.advance(4000);
    r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
    await _flush();
    harness.fireDue();
    await _flush();
    expect(starts.length, 2);
    expect(starts[1] - starts[0], greaterThanOrEqualTo(5000));
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('server interval change n=10 is honored', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
    final FakeClock clock = FakeClock(100000);
    final _TimerHarness harness = _TimerHarness(clock);
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
    r = rig.rig(client, clock: clock, createTimer: harness.createTimer);
    await rig.start(r);
    for (int i = 0; i < 3; i++) {
      clock.advance(10000);
      r.positions.add(rig.pos(8, timestampMs: clock.nowMs()));
      await _flush();
      harness.fireDue();
      await _flush();
    }
    expect(starts.length, greaterThanOrEqualTo(2));
    for (int i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], greaterThanOrEqualTo(10000));
      expect(starts[i] - starts[i - 1], lessThanOrEqualTo(10050));
    }
    await r.controller.endTrip();
    r.controller.dispose();
    await r.positions.close();
  });

  test('ending trip cancels timer, no further requests', () async {
    final List<int> starts = <int>[];
    late rig.Rig r;
    final FakeClock clock = FakeClock(100000);
    final _TimerHarness harness = _TimerHarness(clock);
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
    r = rig.rig(client, clock: clock, createTimer: harness.createTimer);
    await rig.start(r);
    final int before = starts.length;
    await r.controller.endTrip();
    await _flush();
    clock.advance(10000);
    await _flush();
    harness.fireDue();
    await _flush();
    expect(starts.length, before);
    r.controller.dispose();
    await r.positions.close();
  });
}

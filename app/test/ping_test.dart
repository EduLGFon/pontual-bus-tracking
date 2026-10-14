// T32 tests: PingClient semantics from PLAN.md 15.3.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/features/trip/ping_client.dart';

Map<String, dynamic> fix(int seq) => <String, dynamic>{'seq': seq};

PingClient client({
  required Future<PingReply> Function(Map<String, dynamic> body) send,
  int refreshes = 0,
  required void Function() onRefresh,
  required List<Duration> delays,
}) {
  return PingClient(
    send: send,
    refreshToken: () async {
      onRefresh();
    },
    random: Random(1),
    delay: (Duration d) async {
      delays.add(d);
    },
  );
}

void main() {
  test('success delivers the server instruction', () async {
    final List<Duration> delays = <Duration>[];
    final PingClient c = client(
      send: (_) async => const PingReply(status: 200, role: 'L', intervalS: 15),
      onRefresh: () {},
      delays: delays,
    );
    PingOutcome? got;
    c.queue(fix(1), (PingOutcome o) => got = o);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(got?.role, 'L');
    expect(got?.intervalS, 15);
    expect(delays, isEmpty);
  });

  test('timeout backs off 5, 10, 20 with jitter bounds', () async {
    final List<Duration> delays = <Duration>[];
    int calls = 0;
    final PingClient c = client(
      send: (_) async {
        calls += 1;
        if (calls <= 3) {
          throw TimeoutException('down');
        }
        return const PingReply(status: 200, role: 'W', intervalS: 20);
      },
      onRefresh: () {},
      delays: delays,
    );
    PingOutcome? got;
    c.queue(fix(1), (PingOutcome o) => got = o);
    for (int i = 0; i < 20 && got == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(got?.role, 'W');
    expect(delays.length, 3);
    expect(delays[0].inSeconds, inInclusiveRange(3, 7));
    expect(delays[1].inSeconds, inInclusiveRange(8, 12));
    expect(delays[2].inSeconds, inInclusiveRange(18, 22));
  });

  test('401 refreshes once then retries', () async {
    final List<Duration> delays = <Duration>[];
    int calls = 0;
    int refreshes = 0;
    final PingClient c = client(
      send: (_) async {
        calls += 1;
        if (calls == 1) {
          return const PingReply(status: 401);
        }
        return const PingReply(status: 200, role: 'F', intervalS: 90);
      },
      onRefresh: () {
        refreshes += 1;
      },
      delays: delays,
    );
    PingOutcome? got;
    c.queue(fix(1), (PingOutcome o) => got = o);
    for (int i = 0; i < 20 && got == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(refreshes, 1);
    expect(calls, 2);
    expect(got?.role, 'F');
  });

  test('latest fix wins while one is in flight', () async {
    final List<Duration> delays = <Duration>[];
    final List<int> sent = <int>[];
    Completer<PingReply>? gate;
    final PingClient c = client(
      send: (Map<String, dynamic> body) async {
        sent.add(body['seq'] as int);
        if (sent.length == 1) {
          gate = Completer<PingReply>();
          return gate!.future;
        }
        return const PingReply(status: 200, role: 'W', intervalS: 20);
      },
      onRefresh: () {},
      delays: delays,
    );
    int outcomes = 0;
    c.queue(fix(1), (_) => outcomes += 1);
    await Future<void>.delayed(Duration.zero);
    c.queue(fix(2), (_) => outcomes += 1);
    c.queue(fix(3), (_) => outcomes += 1);
    await Future<void>.delayed(Duration.zero);
    gate!.complete(const PingReply(status: 200, role: 'W', intervalS: 20));
    for (int i = 0; i < 20 && outcomes < 2; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sent, <int>[1, 3]);
    expect(outcomes, 2);
  });

  test('server end codes map through', () async {
    for (final String end in <String>[
      'gone',
      'idle',
      'timeout',
      'abuse',
      'maint',
    ]) {
      final List<Duration> delays = <Duration>[];
      final PingClient c = client(
        send: (_) async {
          if (end == 'gone') {
            return const PingReply(status: 404);
          }
          return PingReply(status: 200, role: 'W', intervalS: 20, end: end);
        },
        onRefresh: () {},
        delays: delays,
      );
      PingOutcome? got;
      c.queue(fix(1), (PingOutcome o) => got = o);
      for (int i = 0; i < 20 && got == null; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(got?.end, end);
    }
  });

  test('close drops parked retries and late outcomes', () async {
    int sends = 0;
    int outcomes = 0;
    final Completer<void> gate = Completer<void>();
    final PingClient c = PingClient(
      send: (_) async {
        sends += 1;
        throw TimeoutException('down');
      },
      refreshToken: () async {},
      random: Random(1),
      delay: (_) => gate.future,
    );
    c.queue(fix(1), (_) => outcomes += 1);
    for (int i = 0; i < 20 && sends < 1; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sends, 1);
    // Parked in backoff: closing drops the retry even after the wait ends,
    // and later queues are ignored.
    c.close();
    c.queue(fix(2), (_) => outcomes += 1);
    gate.complete();
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sends, 1);
    expect(outcomes, 0);
  });

  test('a failing refresh backs off instead of escaping to the zone', () async {
    final List<Duration> delays = <Duration>[];
    int calls = 0;
    final PingClient c = PingClient(
      send: (_) async {
        calls += 1;
        if (calls == 1) {
          return const PingReply(status: 401);
        }
        return const PingReply(status: 200, role: 'L', intervalS: 15);
      },
      refreshToken: () async {
        throw TimeoutException('register down');
      },
      random: Random(1),
      delay: (Duration d) async {
        delays.add(d);
      },
    );
    PingOutcome? got;
    c.queue(fix(1), (PingOutcome o) => got = o);
    for (int i = 0; i < 20 && got == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    // The 401 parks in backoff, the retry succeeds: no uncaught error,
    // and the outcome still lands.
    expect(calls, 2);
    expect(delays.length, 1);
    expect(got?.role, 'L');
  });

  test('a 401 after transient errors ends the trip with one refresh', () async {
    final List<Duration> delays = <Duration>[];
    int calls = 0;
    int refreshes = 0;
    final PingClient c = PingClient(
      send: (_) async {
        calls += 1;
        if (calls == 2) {
          return const PingReply(status: 500);
        }
        if (calls >= 3) {
          return const PingReply(status: 401);
        }
        return const PingReply(status: 401);
      },
      refreshToken: () async {
        refreshes += 1;
      },
      random: Random(1),
      delay: (Duration d) async {
        delays.add(d);
      },
    );
    PingOutcome? got;
    c.queue(fix(1), (PingOutcome o) => got = o);
    for (int i = 0; i < 40 && got == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(refreshes, 1);
    expect(got?.end, 'auth');
  });
}

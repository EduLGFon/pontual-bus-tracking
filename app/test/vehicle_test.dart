// T27 tests: snapshot, stream, watchdog, polling fallback, lifecycle.
// Fake clock and fake channel keep everything deterministic.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeSink implements WebSocketSink {
  FakeSink(this.sent, this.doneCompleter);

  final List<String> sent;
  final Completer<void> doneCompleter;

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final dynamic d in stream) {
      add(d);
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!doneCompleter.isCompleted) {
      doneCompleter.complete();
    }
  }

  @override
  Future<void> get done => doneCompleter.future;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
}

class FakeChannel with StreamChannelMixin<dynamic> implements WebSocketChannel {
  FakeChannel()
    : incoming = StreamController<dynamic>(),
      sent = <String>[],
      doneCompleter = Completer<void>() {
    sink = FakeSink(sent, doneCompleter);
  }

  final StreamController<dynamic> incoming;
  final List<String> sent;
  final Completer<void> doneCompleter;

  @override
  // ignore: close_sinks - test fake; closed through dispose() in each test.
  late final FakeSink sink;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  /// Closes the incoming stream. Called at the end of each test.
  Future<void> dispose() async {
    await sink.close();
    await incoming.close();
  }
}

VehicleRepository repo(
  FakeClock clock,
  FakeChannel channel, {
  List<ClientVehicle> snapshot = const <ClientVehicle>[],
}) {
  return VehicleRepository(
    fetchSnapshot: (_) async => snapshot,
    openChannel: (_) async => channel,
    wsBaseUrl: () => 'ws://127.0.0.1:8080',
    clock: clock,
    launch: (Future<void> task) => unawaited(task),
  );
}

const ClientVehicle one = ClientVehicle(
  id: 3,
  lat: -18.72,
  lng: -39.85,
  heading: 90,
  kmh: 29,
  members: 1,
  ageS: 4,
);

void main() {
  test('snapshot first, then stream subscription', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(
      clock,
      channel,
      snapshot: <ClientVehicle>[one],
    );
    await r.start(7);
    expect(r.vehicles.length, 1);
    expect(r.status, StreamStatus.live);
    expect(channel.sent.length, 1);
    expect(channel.sent.first, contains('"op":"sub"'));
    await r.stop();
    expect(r.lineId, isNull);
    await channel.dispose();
  });

  test('stream messages update vehicles and ignore heartbeats', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(clock, channel);
    await r.start(7);
    expect(r.vehicles, isEmpty);
    channel.incoming.add('{"hb":100}');
    channel.incoming.add('{"bye":"restart"}');
    await Future<void>.delayed(Duration.zero);
    expect(r.vehicles, isEmpty);
    channel.incoming.add('{"l":7,"t":100,"v":[[3,-18.72,-39.85,90,29,1,4]]}');
    await Future<void>.delayed(Duration.zero);
    expect(r.vehicles.length, 1);
    expect(r.vehicles.first.id, 3);
    await r.stop();
    await channel.dispose();
  });

  test('watchdog resyncs after 30 s without messages', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    int fetches = 0;
    final VehicleRepository r = VehicleRepository(
      fetchSnapshot: (_) async {
        fetches += 1;
        return <ClientVehicle>[one];
      },
      openChannel: (_) async => channel,
      wsBaseUrl: () => 'ws://127.0.0.1:8080',
      clock: clock,
      launch: (Future<void> task) => unawaited(task),
    );
    await r.start(7);
    expect(fetches, 1);
    // 31 s past the last snapshot resyncs under the 30 s watchdog.
    clock.advance(31000);
    r.debugWatchdogTick();
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 2);
    await r.stop();
    await channel.dispose();
  });

  test('polling fallback arms after 15 s socket-down', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(
      clock,
      channel,
      snapshot: <ClientVehicle>[one],
    );
    await r.start(7);
    expect(r.debugPolling, isFalse);
    r.debugSocketDown();
    // No immediate poller: reconnect covers transient blips first.
    expect(r.debugPolling, isFalse);
    // 16 s down arms the 15 s fallback instead of waiting 30 s.
    clock.advance(16000);
    r.debugWatchdogTick();
    expect(r.debugPolling, isTrue);
    await r.stop();
    expect(r.debugPolling, isFalse);
    await channel.dispose();
  });

  test('heartbeats prove liveness without snapshots', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    int fetches = 0;
    final VehicleRepository r = VehicleRepository(
      fetchSnapshot: (_) async {
        fetches += 1;
        return const <ClientVehicle>[];
      },
      openChannel: (_) async => channel,
      wsBaseUrl: () => 'ws://127.0.0.1:8080',
      clock: clock,
      launch: (Future<void> task) => unawaited(task),
    );
    await r.start(7);
    expect(fetches, 1);
    // A heartbeat at 30 s keeps the quiet-but-connected line from
    // resyncing when the snapshot would otherwise go stale.
    clock.advance(30000);
    channel.incoming.add('{"hb":100}');
    await Future<void>.delayed(Duration.zero);
    clock.advance(20000);
    r.debugWatchdogTick();
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 1);
    // Once the heartbeat itself is stale, resync resumes.
    clock.advance(30000);
    r.debugWatchdogTick();
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 2);
    await r.stop();
    await channel.dispose();
  });

  test('stop closes the socket and clears state', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(
      clock,
      channel,
      snapshot: <ClientVehicle>[one],
    );
    await r.start(7);
    await r.stop();
    await r.stop();
    expect(channel.doneCompleter.isCompleted, isTrue);
    expect(r.lineId, isNull);
    await channel.dispose();
  });

  test('age maths mark stale snapshots', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(
      clock,
      channel,
      snapshot: <ClientVehicle>[one],
    );
    await r.start(7);
    expect(r.status, StreamStatus.live);
    clock.advance(46000);
    r.evaluateAge();
    expect(r.status, StreamStatus.stale);
    await r.stop();
    await channel.dispose();
  });

  test(
    'last position survives a dropped socket with its age ticking',
    () async {
      final FakeClock clock = FakeClock(100000);
      final FakeChannel channel = FakeChannel();
      final VehicleRepository r = repo(
        clock,
        channel,
        snapshot: <ClientVehicle>[one],
      );
      await r.start(7);
      expect(r.vehicles.single.ageS, 4);
      // The server said 4 s at receipt; local elapsed time moves it on.
      clock.advance(10000);
      expect(r.vehicles.single.ageS, 14);
      r.debugSocketDown();
      clock.advance(50000);
      // Age evaluation does not fetch: the last known fix stays put.
      r.evaluateAge();
      // The socket is gone, the last fix stays, and its ping age is honest.
      expect(r.vehicles, hasLength(1));
      expect(r.vehicles.single.id, 3);
      expect(r.vehicles.single.ageS, 64);
      expect(r.status, StreamStatus.stale);
      await r.stop();
      await channel.dispose();
    },
  );

  test('a fresh frame resets the locally advanced age', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(clock, channel);
    await r.start(7);
    channel.incoming.add('{"l":7,"t":100,"v":[[3,-18.72,-39.85,90,29,1,4]]}');
    await Future<void>.delayed(Duration.zero);
    clock.advance(12000);
    expect(r.vehicles.single.ageS, 16);
    channel.incoming.add('{"l":7,"t":115,"v":[[3,-18.72,-39.85,90,29,1,2]]}');
    await Future<void>.delayed(Duration.zero);
    expect(r.vehicles.single.ageS, 2);
    clock.advance(3000);
    expect(r.vehicles.single.ageS, 5);
    await r.stop();
    await channel.dispose();
  });

  test('a failed refresh keeps the last known positions', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    bool fail = false;
    final VehicleRepository r = VehicleRepository(
      fetchSnapshot: (_) async {
        if (fail) {
          throw StateError('offline');
        }
        return <ClientVehicle>[one];
      },
      openChannel: (_) async => channel,
      wsBaseUrl: () => 'ws://127.0.0.1:8080',
      clock: clock,
      launch: (Future<void> task) => unawaited(task),
    );
    await r.start(7);
    expect(r.vehicles, hasLength(1));
    fail = true;
    r.debugSocketDown();
    clock.advance(31000);
    r.debugWatchdogTick();
    await Future<void>.delayed(Duration.zero);
    expect(r.vehicles, hasLength(1));
    expect(r.vehicles.single.ageS, 35);
    expect(r.status, StreamStatus.offline);
    await r.stop();
    await channel.dispose();
  });

  test('reconnects after socket down and resyncs', () async {
    final FakeClock clock = FakeClock(100000);
    final List<FakeChannel> channels = <FakeChannel>[
      FakeChannel(),
      FakeChannel(),
    ];
    int opens = 0;
    int fetches = 0;
    final VehicleRepository r = VehicleRepository(
      fetchSnapshot: (_) async {
        fetches += 1;
        return <ClientVehicle>[one];
      },
      openChannel: (_) async => channels[opens++],
      wsBaseUrl: () => 'ws://127.0.0.1:8080',
      clock: clock,
      launch: (Future<void> task) => unawaited(task),
      reconnectDelays: const <int>[0],
    );
    await r.start(7);
    expect(opens, 1);
    expect(fetches, 1);
    r.debugSocketDown();
    await Future<void>.delayed(Duration.zero);
    expect(opens, 2);
    expect(fetches, 2);
    expect(channels[1].sent.length, 1);
    expect(channels[1].sent.first, contains('"op":"sub"'));
    expect(r.status, StreamStatus.live);
    await r.stop();
    await channels[0].dispose();
    await channels[1].dispose();
  });

  test('no reconnect after stop', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    int opens = 0;
    final VehicleRepository r = VehicleRepository(
      fetchSnapshot: (_) async => const <ClientVehicle>[],
      openChannel: (_) async {
        opens += 1;
        return channel;
      },
      wsBaseUrl: () => 'ws://127.0.0.1:8080',
      clock: clock,
      launch: (Future<void> task) => unawaited(task),
      reconnectDelays: const <int>[60],
    );
    await r.start(7);
    expect(opens, 1);
    r.debugSocketDown();
    await r.stop();
    await Future<void>.delayed(Duration.zero);
    expect(opens, 1);
    await channel.dispose();
  });

  test('frames from a dead socket are ignored', () async {
    final FakeClock clock = FakeClock(100000);
    final FakeChannel channel = FakeChannel();
    final VehicleRepository r = repo(
      clock,
      channel,
      snapshot: <ClientVehicle>[one],
    );
    await r.start(7);
    expect(r.vehicles.length, 1);
    r.debugSocketDown();
    // A half-open socket delivering one delayed duplicate snapshot must
    // not refresh the status or swap the data.
    channel.incoming.add('{"t":100,"v":[[9,-18.8,-39.9,null,0,1,2]]}');
    await Future<void>.delayed(Duration.zero);
    expect(r.vehicles.length, 1);
    expect(r.vehicles.first.id, 3);
    await r.stop();
    await channel.dispose();
  });
}

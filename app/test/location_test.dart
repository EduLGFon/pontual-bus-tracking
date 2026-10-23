// T31 tests: fix filters, rounding, mode settings, permission mapping.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pontual/domain/trip/sampling_policy.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/platform/android/notification_permission.dart';
import 'package:pontual/platform/android/permission_gateway.dart';

void main() {
  test('filter drops mocked, stale, bad, and far fixes', () {
    const RawFix good = RawFix(
      lat: -18.72,
      lng: -39.85,
      accuracyM: 10,
      isMocked: false,
      timestampMs: 100000,
    );
    expect(acceptFix(good, 100000), isTrue);
    expect(
      acceptFix(
        const RawFix(
          lat: -18.72,
          lng: -39.85,
          accuracyM: 10,
          isMocked: true,
          timestampMs: 100000,
        ),
        100000,
      ),
      isFalse,
    );
    expect(acceptFix(good, 100000 + 20001), isFalse);
    expect(
      acceptFix(
        const RawFix(
          lat: -18.72,
          lng: -39.85,
          accuracyM: 500,
          isMocked: false,
          timestampMs: 100000,
        ),
        100000,
      ),
      isFalse,
    );
    expect(
      acceptFix(
        const RawFix(
          lat: -18.0,
          lng: -39.85,
          accuracyM: 10,
          isMocked: false,
          timestampMs: 100000,
        ),
        100000,
      ),
      isFalse,
    );
  });

  test('rounding follows the send format', () {
    expect(round5(-18.723456), closeTo(-18.72346, 1e-9));
    expect(batteryBucket(83), 80);
    expect(batteryBucket(100), 100);
  });

  test('drop reasons name the failing check only', () {
    const RawFix good = RawFix(
      lat: -18.72,
      lng: -39.85,
      accuracyM: 10,
      isMocked: false,
      timestampMs: 100000,
    );
    expect(dropReason(good, 100000), isNull);
    expect(
      dropReason(
        const RawFix(
          lat: -18.72,
          lng: -39.85,
          accuracyM: 10,
          isMocked: true,
          timestampMs: 100000,
        ),
        100000,
      ),
      'mocked',
    );
    expect(dropReason(good, 100000 + 20001), 'stale');
    expect(
      dropReason(
        const RawFix(
          lat: -18.72,
          lng: -39.85,
          accuracyM: 500,
          isMocked: false,
          timestampMs: 100000,
        ),
        100000,
      ),
      'accuracy',
    );
    expect(
      dropReason(
        const RawFix(
          lat: -18.0,
          lng: -39.85,
          accuracyM: 10,
          isMocked: false,
          timestampMs: 100000,
        ),
        100000,
      ),
      'outside',
    );
  });

  test('speed and heading stay inside the server range', () {
    expect(normalizeSpeed(8.34), closeTo(8.3, 1e-9));
    expect(normalizeSpeed(0), 0);
    expect(normalizeSpeed(-1), 0);
    expect(normalizeHeading(90, 8), 90);
    expect(normalizeHeading(0, 8), 0);
    expect(normalizeHeading(360, 8), 0);
    expect(normalizeHeading(-1, 8), isNull);
    expect(normalizeHeading(720, 8), isNull);
    // D66: bearings at standstill are noise, so they are nulled.
    // The 0.5 boundary matches the server still-tick threshold.
    expect(normalizeHeading(90, 0), isNull);
    expect(normalizeHeading(90, 0.4), isNull);
    expect(normalizeHeading(90, 0.5), 90);
    expect(normalizeHeading(360, 0), isNull);
  });

  test('settings carry the foreground notification', () {
    final AndroidSettings waiting =
        settingsFor(SamplingMode.waiting, '60') as AndroidSettings;
    expect(waiting.intervalDuration, const Duration(seconds: 5));
    final AndroidSettings active =
        settingsFor(SamplingMode.leaderMoving, '60') as AndroidSettings;
    expect(active.intervalDuration, const Duration(seconds: 5));
    expect(
      active.foregroundNotificationConfig?.notificationTitle,
      contains('60'),
    );
    final AndroidSettings follower =
        settingsFor(SamplingMode.follower, '60') as AndroidSettings;
    expect(follower.intervalDuration, const Duration(seconds: 45));
    // D63: followers need balanced accuracy so their fixes pass the 60 m
    // gate in weak-GPS areas; low power would starve handovers.
    expect(follower.accuracy, LocationAccuracy.medium);
    // Probes and paused waits stay low power: they carry no handover
    // duty and must cost the least battery.
    final AndroidSettings saver =
        settingsFor(SamplingMode.offlineSaver, '60') as AndroidSettings;
    expect(saver.accuracy, LocationAccuracy.low);
    final AndroidSettings paused =
        settingsFor(SamplingMode.paused, '60') as AndroidSettings;
    expect(paused.accuracy, LocationAccuracy.low);
  });

  test('foreground notification is ongoing and paused keeps the service', () {
    // Background survival: the notification must be persistent and even
    // the paused mode must keep the foreground service, otherwise the OS
    // can kill the process while waiting for GPS to return.
    for (final SamplingMode mode in SamplingMode.values) {
      final LocationSettings settings = settingsFor(mode, '60');
      expect(settings, isA<AndroidSettings>());
      final AndroidSettings android = settings as AndroidSettings;
      expect(
        android.foregroundNotificationConfig,
        isNotNull,
        reason: 'mode $mode must keep the foreground service',
      );
      expect(
        android.foregroundNotificationConfig?.setOngoing,
        isTrue,
        reason: 'mode $mode notification must be persistent',
      );
    }
    final AndroidSettings paused =
        settingsFor(SamplingMode.paused, '60') as AndroidSettings;
    expect(paused.intervalDuration, const Duration(seconds: 45));
  });

  test('upgrades to faster cadence bypass hysteresis', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int opens = 0;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => 100000,
    );
    service.fixes(mode: SamplingMode.waiting, lineLabel: 't');
    expect(opens, 1);
    // Waiting (10 s) to leaderMoving (5 s) is an upgrade: it recreates
    // immediately even inside the 30 s window.
    await service.requestMode(SamplingMode.leaderMoving, 100000 + 1000);
    expect(opens, 2);
    // LeaderMoving (5 s) to follower (45 s) is a downgrade: it waits out
    // the hysteresis window.
    await service.requestMode(SamplingMode.follower, 100000 + 2000);
    expect(opens, 2);
    service.stop();
    await positions.close();
  });

  test('gateway constructs without platform calls', () {
    expect(const GeolocatorPermissionGateway(), isNotNull);
  });

  test('slow battery reads never delay fixes', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    final LocationService service = LocationService(
      positionStream: (_) => positions.stream,
      batteryLevel: () async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return 80;
      },
      charging: () async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return false;
      },
      nowMs: () => 100000,
    );
    final Future<TripFix> first = service
        .fixes(mode: SamplingMode.waiting, lineLabel: 't')
        .first;
    positions.add(
      Position(
        latitude: -18.72,
        longitude: -39.85,
        timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
        accuracy: 10,
        altitude: 0,
        heading: 90,
        speed: 8,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
    );
    // Would timeout if the fix waited for the 3 s battery reads.
    final TripFix fix = await first.timeout(const Duration(seconds: 1));
    expect(fix.seq, 1);
    service.stop();
    await positions.close();
  });

  test('notification permission request never throws off-device', () async {
    await ensureNotificationPermission().timeout(const Duration(seconds: 10));
  });

  test('battery failures keep fixes flowing with last values', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    final LocationService service = LocationService(
      positionStream: (_) => positions.stream,
      batteryLevel: () async => throw StateError('no battery'),
      charging: () async => throw StateError('no battery'),
      nowMs: () => 100000,
    );
    final Future<TripFix> first = service
        .fixes(mode: SamplingMode.waiting, lineLabel: 't')
        .first;
    positions.add(
      Position(
        latitude: -18.72,
        longitude: -39.85,
        timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
        accuracy: 10,
        altitude: 0,
        heading: 90,
        speed: 0,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
    );
    final TripFix fix = await first.timeout(const Duration(seconds: 5));
    expect(fix.seq, 1);
    expect(fix.batteryPct, 100);
    expect(fix.charging, isFalse);
    service.stop();
    await positions.close();
  });

  test('battery reads are cached within the TTL', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int reads = 0;
    final LocationService service = LocationService(
      positionStream: (_) => positions.stream,
      batteryLevel: () async {
        reads += 1;
        return 80;
      },
      charging: () async => false,
      nowMs: () => 100000,
    );
    final Stream<TripFix> stream = service.fixes(
      mode: SamplingMode.waiting,
      lineLabel: 't',
    );
    Position atMs(int ms) => Position(
      latitude: -18.72,
      longitude: -39.85,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ms),
      accuracy: 10,
      altitude: 0,
      heading: 90,
      speed: 0,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
    );
    // Fixes emit immediately with the last known bucket and refresh the
    // cache in the background: the first fix carries the 100 default while
    // the refresh lands, later fixes carry the refreshed 80.
    final Future<List<TripFix>> two = stream.take(2).toList();
    positions.add(atMs(100000));
    positions.add(atMs(100000));
    final List<TripFix> fixes = await two.timeout(const Duration(seconds: 5));
    expect(fixes.length, 2);
    // Let the background refresh finish before asserting the read count.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(reads, 1);
    expect(fixes[0].batteryPct, 100);
    // The next fix after the refresh carries the new bucket.
    final Future<TripFix> third = stream.first;
    positions.add(atMs(100000));
    final TripFix next = await third.timeout(const Duration(seconds: 5));
    expect(next.batteryPct, 80);
    expect(reads, 1);
    service.stop();
    await positions.close();
  });

  test('a dead position stream restarts without waiting hysteresis', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int opens = 0;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => 100000,
    );
    service.fixes(mode: SamplingMode.waiting, lineLabel: 't');
    expect(opens, 1);
    // Same mode inside hysteresis restarts nothing while healthy.
    await service.requestMode(SamplingMode.waiting, 100000);
    expect(opens, 1);
    // The OS kills the position stream when location services go off.
    positions.addError(StateError('location off'));
    await Future<void>.delayed(Duration.zero);
    await service.requestMode(SamplingMode.waiting, 100000);
    expect(opens, 2);
    service.stop();
    await positions.close();
  });

  test('degraded accuracy extends the downgrade guard', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int now = 100000;
    int opens = 0;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => now,
    );
    final Stream<TripFix> stream = service.fixes(
      mode: SamplingMode.leaderMoving,
      lineLabel: 't',
    );
    expect(opens, 1);
    Position fixWith(double acc) => Position(
      latitude: -18.72,
      longitude: -39.85,
      timestamp: DateTime.fromMillisecondsSinceEpoch(now),
      accuracy: acc,
      altitude: 0,
      heading: 90,
      speed: 8,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
    );
    Future<void> emitDegraded() async {
      final Future<TripFix> next = stream.first;
      positions.add(fixWith(50));
      await next.timeout(const Duration(seconds: 5));
    }

    await emitDegraded();
    // Past the normal 30 s window but inside the 60 s degraded hold:
    // the faster stream stays up so the next good fix arrives sooner.
    now = 100000 + 31000;
    await emitDegraded();
    expect(
      await service.requestMode(SamplingMode.follower, now),
      SamplingMode.leaderMoving,
    );
    expect(opens, 1);
    now = 100000 + 45000;
    await emitDegraded();
    expect(
      await service.requestMode(SamplingMode.follower, now),
      SamplingMode.leaderMoving,
    );
    expect(opens, 1);
    // Past the degraded hold: the downgrade recreates the stream.
    now = 100000 + 61000;
    await emitDegraded();
    expect(
      await service.requestMode(SamplingMode.follower, now),
      SamplingMode.follower,
    );
    expect(opens, 2);
    service.stop();
    await positions.close();
  });

  test('good accuracy keeps the normal downgrade guard', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int now = 100000;
    int opens = 0;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => now,
    );
    final Stream<TripFix> stream = service.fixes(
      mode: SamplingMode.leaderMoving,
      lineLabel: 't',
    );
    // Just under the 40 m degraded line: normal 30 s guard applies.
    now = 100000 + 30000;
    final Future<TripFix> next = stream.first;
    positions.add(
      Position(
        latitude: -18.72,
        longitude: -39.85,
        timestamp: DateTime.fromMillisecondsSinceEpoch(now),
        accuracy: 39,
        altitude: 0,
        heading: 90,
        speed: 8,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
    );
    await next.timeout(const Duration(seconds: 5));
    now = 100000 + 31000;
    expect(
      await service.requestMode(SamplingMode.follower, now),
      SamplingMode.follower,
    );
    expect(opens, 2);
    service.stop();
    await positions.close();
  });

  test('degraded hold never delays offline saver or paused', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int now = 100000;
    int opens = 0;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => now,
    );
    final Stream<TripFix> stream = service.fixes(
      mode: SamplingMode.leaderMoving,
      lineLabel: 't',
    );
    Future<void> emitDegraded() async {
      final Future<TripFix> next = stream.first;
      positions.add(
        Position(
          latitude: -18.72,
          longitude: -39.85,
          timestamp: DateTime.fromMillisecondsSinceEpoch(now),
          accuracy: 50,
          altitude: 0,
          heading: 90,
          speed: 8,
          speedAccuracy: 1,
          altitudeAccuracy: 1,
          headingAccuracy: 1,
        ),
      );
      await next.timeout(const Duration(seconds: 5));
    }

    // Inside the degraded 60 s hold but past the normal 30 s window:
    // saver and paused still switch on the normal guard.
    now = 100000 + 44000;
    await emitDegraded();
    now = 100000 + 45000;
    expect(
      await service.requestMode(SamplingMode.offlineSaver, now),
      SamplingMode.offlineSaver,
    );
    expect(opens, 2);
    now = 100000 + 75000;
    await emitDegraded();
    now = 100000 + 76000;
    expect(
      await service.requestMode(SamplingMode.paused, now),
      SamplingMode.paused,
    );
    expect(opens, 3);
    service.stop();
    await positions.close();
  });

  test(
    'recovery restarts a silent stream and accepts a one-shot fix',
    () async {
      // ignore: close_sinks - closed at the end of the test.
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      int opens = 0;
      int now = 100000;
      int oneShots = 0;
      final LocationService service = LocationService(
        positionStream: (_) {
          opens += 1;
          return positions.stream;
        },
        oneShotPosition: (_) async {
          oneShots += 1;
          return Position(
            latitude: -18.72,
            longitude: -39.85,
            timestamp: DateTime.fromMillisecondsSinceEpoch(now),
            accuracy: 10,
            altitude: 0,
            heading: 90,
            speed: 8,
            speedAccuracy: 1,
            altitudeAccuracy: 1,
            headingAccuracy: 1,
          );
        },
        batteryLevel: () async => 80,
        charging: () async => false,
        nowMs: () => now,
      );
      final Stream<TripFix> stream = service.fixes(
        mode: SamplingMode.waiting,
        lineLabel: 't',
      );
      Position atNow() => Position(
        latitude: -18.72,
        longitude: -39.85,
        timestamp: DateTime.fromMillisecondsSinceEpoch(now),
        accuracy: 10,
        altitude: 0,
        heading: 90,
        speed: 8,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );
      final Future<TripFix> first = stream.first;
      positions.add(atNow());
      await first.timeout(const Duration(seconds: 5));
      expect(opens, 1);
      now += LocationService.stallRestartMs + 1000;
      final Future<TripFix> recovered = stream.first;
      expect(await service.recoverNow(), isTrue);
      expect(oneShots, 1);
      expect(opens, 2);
      final TripFix fix = await recovered.timeout(const Duration(seconds: 5));
      expect(fix.seq, 2);
      service.stop();
      await positions.close();
    },
  );

  test(
    'recovery keeps a healthy stream and ignores a failing one-shot',
    () async {
      // ignore: close_sinks - closed at the end of the test.
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      int opens = 0;
      final LocationService service = LocationService(
        positionStream: (_) {
          opens += 1;
          return positions.stream;
        },
        oneShotPosition: (_) async => throw StateError('no fix'),
        batteryLevel: () async => 80,
        charging: () async => false,
        nowMs: () => 100000,
      );
      final Stream<TripFix> stream = service.fixes(
        mode: SamplingMode.waiting,
        lineLabel: 't',
      );
      final Future<TripFix> first = stream.first;
      positions.add(
        Position(
          latitude: -18.72,
          longitude: -39.85,
          timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
          accuracy: 10,
          altitude: 0,
          heading: 90,
          speed: 8,
          speedAccuracy: 1,
          altitudeAccuracy: 1,
          headingAccuracy: 1,
        ),
      );
      await first.timeout(const Duration(seconds: 5));
      // Last fix is fresh, so no restart is needed; the failed one-shot is
      // swallowed and the regular stream keeps working.
      expect(await service.recoverNow(), isFalse);
      expect(opens, 1);
      service.stop();
      await positions.close();
    },
  );

  test('a silent stream restarts after the stall window', () async {
    // ignore: close_sinks - closed at the end of the test.
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    int opens = 0;
    int now = 100000;
    final LocationService service = LocationService(
      positionStream: (_) {
        opens += 1;
        return positions.stream;
      },
      batteryLevel: () async => 80,
      charging: () async => false,
      nowMs: () => now,
    );
    final Stream<TripFix> stream = service.fixes(
      mode: SamplingMode.waiting,
      lineLabel: 't',
    );
    final Future<TripFix> first = stream.first;
    positions.add(
      Position(
        latitude: -18.72,
        longitude: -39.85,
        timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
        accuracy: 10,
        altitude: 0,
        heading: 90,
        speed: 8,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      ),
    );
    await first.timeout(const Duration(seconds: 5));
    expect(opens, 1);
    // Inside the stall window the same mode restarts nothing.
    now = 100000 + LocationService.stallRestartMs - 1000;
    await service.requestMode(SamplingMode.waiting, now);
    expect(opens, 1);
    // Past it with no fix since, the stream recreates.
    now = 100000 + LocationService.stallRestartMs + 1000;
    await service.requestMode(SamplingMode.waiting, now);
    expect(opens, 2);
    service.stop();
    await positions.close();
  });
}

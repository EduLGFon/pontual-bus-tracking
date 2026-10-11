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
    expect(normalizeHeading(90), 90);
    expect(normalizeHeading(0), 0);
    expect(normalizeHeading(360), 0);
    expect(normalizeHeading(-1), isNull);
    expect(normalizeHeading(720), isNull);
  });

  test('settings carry the foreground notification', () {
    final LocationSettings waiting = settingsFor(SamplingMode.waiting, '60');
    expect(waiting, isA<AndroidSettings>());
    final AndroidSettings active =
        settingsFor(SamplingMode.leaderMoving, '60') as AndroidSettings;
    expect(active.intervalDuration, const Duration(seconds: 12));
    expect(
      active.foregroundNotificationConfig?.notificationTitle,
      contains('60'),
    );
    final AndroidSettings follower =
        settingsFor(SamplingMode.follower, '60') as AndroidSettings;
    expect(follower.intervalDuration, const Duration(seconds: 90));
  });

  test('gateway constructs without platform calls', () {
    expect(const GeolocatorPermissionGateway(), isNotNull);
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
    final Future<List<TripFix>> two = stream.take(2).toList();
    positions.add(atMs(100000));
    positions.add(atMs(100000));
    final List<TripFix> fixes = await two.timeout(const Duration(seconds: 5));
    expect(fixes.length, 2);
    expect(reads, 1);
    expect(fixes[0].batteryPct, 80);
    service.stop();
    await positions.close();
  });
}

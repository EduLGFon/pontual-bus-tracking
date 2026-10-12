// Unit tests for the sharing health model: one row per state in the
// trip.md table, plus priority when several issues fire at once.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/trip/sharing_health.dart';

SharingSignals base() {
  return const SharingSignals(
    ended: false,
    isStarting: false,
    offline: false,
    servicesOn: true,
    permissionGranted: true,
    nowMs: 100000,
    accuracyM: 10,
    lastSuccessMs: 99000,
    startedAtMs: 0,
    batteryPct: 80,
  );
}

void main() {
  test('all good is live with no banner', () {
    final SharingHealth h = resolveSharingHealth(base());
    expect(h.overall, SharingOverall.live);
    expect(h.issue, SharingIssue.none);
    expect(h.connectionValue, ConnectionValue.connected);
    expect(h.gpsValue, GpsValue.good);
    expect(h.deviceValue, DeviceValue.screenOn);
    expect(h.connectionLevel, SharingLevel.ok);
    expect(h.lastSendStale, isFalse);
  });

  test('offline pauses with the offline banner', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: true,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        accuracyM: 10,
        lastSuccessMs: 0,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.overall, SharingOverall.paused);
    expect(h.issue, SharingIssue.offline);
    expect(h.connectionValue, ConnectionValue.offline);
    expect(h.deviceValue, DeviceValue.screenOn);
  });

  test('startup grace suppresses the offline banner', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: true,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 1000,
        startedAtMs: 0,
      ),
    );
    expect(h.overall, SharingOverall.starting);
    expect(h.issue, SharingIssue.none);
    expect(h.connectionValue, ConnectionValue.reconnecting);
    expect(h.gpsValue, GpsValue.searching);
  });

  test('starting state is neutral', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: true,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        startedAtMs: 100000,
      ),
    );
    expect(h.overall, SharingOverall.starting);
    expect(h.connectionLevel, SharingLevel.neutral);
    expect(h.gpsValue, GpsValue.searching);
  });

  test('location off beats offline', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: true,
        servicesOn: false,
        permissionGranted: true,
        nowMs: 100000,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.issue, SharingIssue.locationOff);
    expect(h.gpsValue, GpsValue.off);
    expect(h.gpsLevel, SharingLevel.error);
  });

  test('permission revoked beats everything', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: true,
        servicesOn: false,
        permissionGranted: false,
        nowMs: 100000,
        accuracyM: 50,
        lastSuccessMs: 0,
        startedAtMs: 0,
        batteryPct: 5,
      ),
    );
    expect(h.issue, SharingIssue.permission);
    expect(h.gpsValue, GpsValue.noPermission);
    expect(h.overall, SharingOverall.paused);
  });

  test('weak GPS pauses with the weak banner', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        accuracyM: 45,
        lastSuccessMs: 99000,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.issue, SharingIssue.gpsWeak);
    expect(h.gpsValue, GpsValue.weak);
    expect(h.overall, SharingOverall.paused);
  });

  test('no fix pauses with the no-fix issue', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.issue, SharingIssue.gpsNoFix);
    expect(h.gpsValue, GpsValue.noFix);
  });

  test('low battery pauses only when nothing else fires', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        accuracyM: 10,
        lastSuccessMs: 99000,
        startedAtMs: 0,
        batteryPct: 10,
      ),
    );
    expect(h.issue, SharingIssue.lowBattery);
    expect(h.deviceValue, DeviceValue.lowBattery);
    expect(h.deviceLevel, SharingLevel.warn);
  });

  test('charging exempts low battery', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        accuracyM: 10,
        lastSuccessMs: 99000,
        startedAtMs: 0,
        batteryPct: 5,
        charging: true,
      ),
    );
    expect(h.issue, SharingIssue.none);
    expect(h.overall, SharingOverall.live);
  });

  test('stale last send flags amber while online', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: false,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        accuracyM: 10,
        lastSuccessMs: 0,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.lastSendStale, isTrue);
    expect(h.overall, SharingOverall.live);
  });

  test('ended suppresses every banner', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: true,
        isStarting: false,
        offline: true,
        servicesOn: false,
        permissionGranted: false,
        nowMs: 100000,
        startedAtMs: 0,
      ),
    );
    expect(h.overall, SharingOverall.ended);
    expect(h.issue, SharingIssue.none);
  });

  test('device tile never carries connectivity', () {
    final SharingHealth h = resolveSharingHealth(
      const SharingSignals(
        ended: false,
        isStarting: false,
        offline: true,
        servicesOn: true,
        permissionGranted: true,
        nowMs: 100000,
        startedAtMs: 0,
        batteryPct: 80,
      ),
    );
    expect(h.deviceValue, DeviceValue.screenOn);
  });
}

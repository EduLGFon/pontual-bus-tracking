// T34 tests: TripSupervisor evaluation without HTTP, plus the pure
// walking-prompt and sampling helpers. See PLAN.md 8.6, 11.3, RF16.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/trip/auto_end.dart';
import 'package:pontual/domain/trip/sampling_policy.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/trip_supervisor.dart';

/// Controllable gateway for supervision tests.
class FakeGateway implements PermissionGateway {
  /// Current permission answer.
  LocationPermissionState permission = LocationPermissionState.granted;

  /// Location services answer.
  bool services = true;

  /// Precise-accuracy answer. False models an approximate-only grant.
  bool precise = true;

  /// When true, both probes throw.
  bool throwing = false;

  @override
  Future<LocationPermissionState> check() async {
    if (throwing) {
      throw StateError('check failed');
    }
    return permission;
  }

  @override
  Future<LocationPermissionState> request() async => permission;

  @override
  Future<bool> servicesOn() async {
    if (throwing) {
      throw StateError('services failed');
    }
    return services;
  }

  @override
  Future<bool> preciseAccuracy() async => precise;

  @override
  Future<void> openSettings() async {}
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
    acceptedAtMs: 0,
  );
}

void main() {
  test('walking prompt appears after 4 min slow', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    supervisor.onFix(fix(0), 0);
    Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs - 1,
    );
    expect(round.promptVisible, isFalse);
    round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs,
    );
    expect(round.promptVisible, isTrue);
    expect(round.endReason, isNull);
  });

  test('walking timeout without answer ends the trip', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    supervisor.onFix(fix(0), 0);
    supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs,
    );
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs + walkingTimeoutMs + 1,
    );
    expect(round.endReason, AutoEndReason.walkingTimeout);
  });

  test('confirming still riding restarts the slow clock', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    supervisor.onFix(fix(0), 0);
    supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs,
    );
    expect(supervisor.promptVisible, isTrue);
    supervisor.confirmStillRiding();
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs + walkingTimeoutMs + 1,
    );
    expect(round.promptVisible, isFalse);
    expect(round.endReason, isNull);
  });

  test('moving fixes clear the slow clock', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    supervisor.onFix(fix(0), 0);
    supervisor.onFix(fix(8), walkingPromptAfterMs - 1);
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: walkingPromptAfterMs,
    );
    expect(round.promptVisible, isFalse);
  });

  test('gps off pauses first and ends after 5 min', () async {
    final FakeGateway gateway = FakeGateway()..services = false;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    await supervisor.pollEnvironment(1000);
    Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 1000,
    );
    expect(round.paused, isTrue);
    expect(round.wanted, SamplingMode.paused);
    expect(round.endReason, isNull);
    await supervisor.pollEnvironment(1000 + gpsOffAfterMs + 1);
    round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 1000 + gpsOffAfterMs + 1,
    );
    expect(round.endReason, AutoEndReason.gpsOff);
  });

  test('permission revoked after 3 consecutive polls', () async {
    final FakeGateway gateway = FakeGateway()
      ..permission = LocationPermissionState.denied;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    Future<AutoEndReason?> round(int nowMs) async {
      await supervisor.pollEnvironment(nowMs);
      return supervisor
          .evaluate(
            role: 'L',
            failures: 0,
            wasOffline: false,
            startedAtMs: 0,
            nowMs: nowMs,
          )
          .endReason;
    }

    expect(await round(1000), isNull);
    expect(await round(2000), isNull);
    expect(await round(3000), AutoEndReason.permissionRevoked);
  });

  test('permission flap does not end the trip', () async {
    final FakeGateway gateway = FakeGateway()
      ..permission = LocationPermissionState.denied;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    await supervisor.pollEnvironment(1000);
    await supervisor.pollEnvironment(2000);
    gateway.permission = LocationPermissionState.granted;
    await supervisor.pollEnvironment(3000);
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 3000,
    );
    expect(round.endReason, isNull);
  });

  test(
    'three approximate polls flag imprecise with low-power sampling',
    () async {
      final FakeGateway gateway = FakeGateway()..precise = false;
      final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
      supervisor.begin(0);
      await supervisor.pollEnvironment(1000);
      await supervisor.pollEnvironment(2000);
      expect(supervisor.imprecise, isFalse);
      await supervisor.pollEnvironment(3000);
      expect(supervisor.imprecise, isTrue);
      final Supervision round = supervisor.evaluate(
        role: 'L',
        failures: 0,
        wasOffline: false,
        startedAtMs: 0,
        nowMs: 3000,
      );
      expect(round.imprecise, isTrue);
      expect(round.wanted, SamplingMode.paused);
      // Sampling matches paused, but the reported flag stays false so
      // the UI shows the Precise guidance, not the location-off banner.
      expect(round.paused, isFalse);
      // Never ends the trip by itself: the server timeout bounds the
      // zombie, and a fixed grant resumes without a restart.
      expect(round.endReason, isNull);
    },
  );

  test('a precise poll forgives imprecise', () async {
    final FakeGateway gateway = FakeGateway()..precise = false;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    await supervisor.pollEnvironment(1000);
    await supervisor.pollEnvironment(2000);
    await supervisor.pollEnvironment(3000);
    expect(supervisor.imprecise, isTrue);
    gateway.precise = true;
    await supervisor.pollEnvironment(4000);
    expect(supervisor.imprecise, isFalse);
  });

  test('flowing fixes forgive permission flaps', () async {
    final FakeGateway gateway = FakeGateway()
      ..permission = LocationPermissionState.denied;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    await supervisor.pollEnvironment(1000);
    await supervisor.pollEnvironment(2000);
    // Positions still flow: the polls flapped, nothing was revoked.
    supervisor.onFix(fix(8), 2500);
    await supervisor.pollEnvironment(3000);
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 3000,
    );
    expect(round.endReason, isNull);
    expect(supervisor.permissionRevoked, isFalse);
  });

  test('max duration ends the trip', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    final Supervision round = supervisor.evaluate(
      role: 'F',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: tripMaxMs + 1,
    );
    expect(round.endReason, AutoEndReason.maxDuration);
  });

  test('offline after failures or silence, success heals', () {
    final FakeGateway gateway = FakeGateway();
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    Supervision round = supervisor.evaluate(
      role: 'F',
      failures: 3,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 1000,
    );
    expect(round.offline, isTrue);
    expect(round.wanted, SamplingMode.offlineSaver);
    supervisor.reset();
    supervisor.begin(0);
    round = supervisor.evaluate(
      role: 'F',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: offlineAfterMs + 1,
    );
    expect(round.offline, isTrue);
    // A success resets the silence clock. The controller owns the
    // offline-to-online edge (wentOnline); the next round evaluated
    // with wasOffline false stays online.
    supervisor.onPingSuccess(offlineAfterMs + 1);
    round = supervisor.evaluate(
      role: 'F',
      failures: 0,
      wasOffline: true,
      startedAtMs: 0,
      nowMs: offlineAfterMs + 2,
    );
    expect(round.offline, isTrue);
    round = supervisor.evaluate(
      role: 'F',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: offlineAfterMs + 2,
    );
    expect(round.offline, isFalse);
  });

  test('failing polls keep previous values', () async {
    final FakeGateway gateway = FakeGateway()..throwing = true;
    final TripSupervisor supervisor = TripSupervisor(gateway: gateway);
    supervisor.begin(0);
    await supervisor.pollEnvironment(1000);
    final Supervision round = supervisor.evaluate(
      role: 'L',
      failures: 0,
      wasOffline: false,
      startedAtMs: 0,
      nowMs: 1000,
    );
    expect(round.endReason, isNull);
    expect(round.paused, isFalse);
  });

  test('walking prompt due is pure', () {
    expect(
      walkingPromptDue(slowSinceMs: null, promptAtMs: null, nowMs: 1000),
      isFalse,
    );
    expect(
      walkingPromptDue(slowSinceMs: 0, promptAtMs: 1, nowMs: 1000000),
      isFalse,
    );
    expect(
      walkingPromptDue(
        slowSinceMs: 0,
        promptAtMs: null,
        nowMs: walkingPromptAfterMs - 1,
      ),
      isFalse,
    );
    expect(
      walkingPromptDue(
        slowSinceMs: 0,
        promptAtMs: null,
        nowMs: walkingPromptAfterMs,
      ),
      isTrue,
    );
  });

  test('wanted mode covers offline and paused', () {
    TripModeInput input({
      String role = 'L',
      bool offline = false,
      bool paused = false,
    }) {
      return TripModeInput(
        role: role,
        speedMps: 8,
        offline: offline,
        stillS: 0,
        paused: paused,
      );
    }

    expect(wantedMode(input()), SamplingMode.leaderMoving);
    expect(wantedMode(input(offline: true)), SamplingMode.offlineSaver);
    expect(wantedMode(input(paused: true)), SamplingMode.paused);
    expect(wantedMode(input(role: 'F')), SamplingMode.follower);
  });
}

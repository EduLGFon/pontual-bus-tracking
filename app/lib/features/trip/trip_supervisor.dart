// TripSupervisor: tracks trip health (location services, permission,
// slowness, ping success) and evaluates auto-end, offline-saver, and
// sampling decisions. TripController applies the decisions to the state
// machine and owns all I/O. See PLAN.md 8.6, 11.3, RF04, and RF16.
// ignore_for_file: prefer_initializing_formals - injected fakes keep
// stable public names while the fields stay private.
import 'package:pontual/domain/trip/auto_end.dart';
import 'package:pontual/domain/trip/sampling_policy.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/features/trip/permission_sheet.dart';

/// Consecutive failed sends before offline saver.
const int offlineAfterFailures = 3;

/// Consecutive non-granted permission polls before treating the
/// permission as revoked. The web Permissions API can flap to "prompt"
/// while positions flow (notably Firefox); one bad poll must not end
/// a healthy trip. A real revoke persists and still ends it. See D29.
const int permissionRevokedAfterPolls = 3;

/// Milliseconds without a successful ping before offline saver.
const int offlineAfterMs = 120 * 1000;

/// One supervision round applied by TripController.
class Supervision {
  /// Creates a supervision decision.
  const Supervision({
    required this.promptVisible,
    required this.offline,
    required this.paused,
    required this.endReason,
    required this.wanted,
  });

  /// True while the RF16 walking prompt should be on screen.
  final bool promptVisible;

  /// True while only probes go out (offline saver).
  final bool offline;

  /// True while location services are off (stream paused).
  final bool paused;

  /// Set when the trip must end now.
  final AutoEndReason? endReason;

  /// Sampling mode the location service should use.
  final SamplingMode wanted;
}

/// Tracks trip health and evaluates supervision rounds.
class TripSupervisor {
  /// Creates a supervisor polling [gateway] for environment changes.
  TripSupervisor({required PermissionGateway gateway}) : _gateway = gateway;

  final PermissionGateway _gateway;

  int? _gpsOffSinceMs;
  bool _permissionRevoked = false;
  int _permissionBadPolls = 0;
  int? _walkingPromptAtMs;
  int? _slowSinceMs;
  int? _lastSuccessMs;
  double _lastSpeedMps = 0;

  /// True while the RF16 walking prompt should be on screen.
  bool get promptVisible => _walkingPromptAtMs != null;

  /// True while location services are off.
  bool get paused => _gpsOffSinceMs != null;

  /// Last successful ping in ms, null before the first success.
  /// Read-only for the health model.
  int? get lastSuccessMs => _lastSuccessMs;

  /// True after 3 consecutive non-granted polls. Read-only.
  bool get permissionRevoked => _permissionRevoked;

  /// Seeds the success clock at trip start.
  void begin(int nowMs) {
    _lastSuccessMs = nowMs;
  }

  /// Polls permission and location services. Failing polls keep the
  /// previous values so a broken check never ends trips. Fail safe:
  /// revocation ends the trip on the next evaluation.
  Future<void> pollEnvironment(int nowMs) async {
    try {
      final LocationPermissionState perm = await _gateway.check();
      if (perm == LocationPermissionState.granted) {
        _permissionBadPolls = 0;
        _permissionRevoked = false;
      } else {
        _permissionBadPolls += 1;
        if (_permissionBadPolls >= permissionRevokedAfterPolls) {
          _permissionRevoked = true;
        }
      }
    } catch (_) {
      // Keep the previous value.
    }
    try {
      final bool on = await _gateway.servicesOn();
      if (on) {
        _gpsOffSinceMs = null;
      } else {
        _gpsOffSinceMs ??= nowMs;
      }
    } catch (_) {
      // Keep the previous value.
    }
  }

  /// Tracks slow movement for the RF16 prompt. Call per accepted fix.
  void onFix(TripFix fix, int nowMs) {
    _lastSpeedMps = fix.speedMps;
    // An accepted fix proves location access works right now. The web
    // Permissions API can report "prompt" for polls in a row while
    // positions keep flowing (notably Firefox); that flap must never end
    // a healthy trip. A real revoke stops the stream, so no fix arrives
    // to forgive it.
    _permissionBadPolls = 0;
    _permissionRevoked = false;
    if (fix.speedMps < walkingSlowMaxMps) {
      _slowSinceMs ??= nowMs;
    } else {
      _slowSinceMs = null;
    }
    if (walkingPromptDue(
      slowSinceMs: _slowSinceMs,
      promptAtMs: _walkingPromptAtMs,
      nowMs: nowMs,
    )) {
      _walkingPromptAtMs = nowMs;
    }
  }

  /// Resets the silence clock. Call per successful ping.
  void onPingSuccess(int nowMs) {
    _lastSuccessMs = nowMs;
  }

  /// Evaluates one round. [role] is the last server role (L, F, W),
  /// [failures] the ping client's consecutive failures, [wasOffline]
  /// the controller's current offline state.
  Supervision evaluate({
    required String role,
    required int failures,
    required bool wasOffline,
    required int startedAtMs,
    required int nowMs,
  }) {
    if (walkingPromptDue(
      slowSinceMs: _slowSinceMs,
      promptAtMs: _walkingPromptAtMs,
      nowMs: nowMs,
    )) {
      _walkingPromptAtMs = nowMs;
    }
    final AutoEndReason? endReason = autoEndReason(
      AutoEndInput(
        startedAtMs: startedAtMs,
        gpsOffSinceMs: _gpsOffSinceMs,
        permissionRevoked: _permissionRevoked,
        walkingPromptAtMs: _walkingPromptAtMs,
      ),
      nowMs,
    );
    final int sinceSuccess = nowMs - (_lastSuccessMs ?? nowMs);
    final bool offline =
        wasOffline ||
        failures >= offlineAfterFailures ||
        sinceSuccess > offlineAfterMs;
    final int stillS = _slowSinceMs == null
        ? 0
        : (nowMs - _slowSinceMs!) ~/ 1000;
    final SamplingMode wanted = wantedMode(
      TripModeInput(
        role: role,
        speedMps: _lastSpeedMps,
        offline: offline,
        stillS: stillS,
        paused: paused,
      ),
    );
    return Supervision(
      promptVisible: promptVisible,
      offline: offline,
      paused: paused,
      endReason: endReason,
      wanted: wanted,
    );
  }

  /// RF16: the user is still on the bus. Hides the prompt and restarts
  /// the slow-speed clock for another 15 minutes.
  void confirmStillRiding() {
    _walkingPromptAtMs = null;
    _slowSinceMs = null;
  }

  /// Clears all tracking at trip end.
  void reset() {
    _gpsOffSinceMs = null;
    _permissionRevoked = false;
    _permissionBadPolls = 0;
    _walkingPromptAtMs = null;
    _slowSinceMs = null;
    _lastSuccessMs = null;
    _lastSpeedMps = 0;
  }
}

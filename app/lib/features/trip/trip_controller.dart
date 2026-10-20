// TripController: the only place that starts or stops the foreground
// service and sends pings. Orchestrates consent, permission,
// registration, start, fixes, ping outcomes, auto-end, and manual end.
// Widgets read state and call methods; they hold no logic.
// See PLAN.md 8.5, 14.3, and S08.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/domain/trip/auto_end.dart';
import 'package:pontual/domain/trip/sampling_policy.dart';
import 'package:pontual/domain/trip/share_phases.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:pontual/domain/trip/trip_state.dart';
import 'package:pontual/features/trip/consent_flow.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/ping_client.dart';
import 'package:pontual/features/trip/trip_supervisor.dart';
import 'package:pontual/platform/android/gnss_quality.dart';

/// Why the last [TripController.startTrip] returned false. Null when the
/// last start succeeded or none ran. Read by the share flow to explain
/// the failure instead of failing silently.
enum StartFailure {
  /// User declined or dismissed the consent sheet. Stays silent.
  declined,

  /// OS permission denied; the flow shows the permission sheets.
  permission,

  /// Granted but approximate-only; the flow asks for Precise instead
  /// of stalling at "waiting for GPS". See D67.
  imprecise,

  /// Network or registration failure.
  offline,

  /// No location fix within the wait window.
  noGps,

  /// Server rate, quota, capacity, or maintenance limits.
  busy,

  /// Fix outside the served area.
  outsideArea,

  /// Anything else, including consent mismatches after reposting.
  failed,
}

/// Preferred first-fix accuracy in meters for a trip start. The start
/// waits for a fix this good inside the GPS window when one arrives and
/// falls back to the best-seen accepted fix, so a lone coarse fix never
/// anchors the vehicle when a good one follows seconds later. Well
/// under the 60 m publish gate: this never drops a fix. See D65.
const double firstFixGoodAccuracyM = 30;

/// Server trip timeout fallback in milliseconds. PLAN.md RF04 and the
/// server default are 10 minutes. The client never uses this to end a
/// trip; it only recognizes that a long web hide probably outlived the
/// server record, so the first `gone` after returning is shown as a
/// timeout instead of silently reviving with a stale fix.
const int webTripTimeoutFallbackMs = 10 * 60 * 1000;

/// Trip end reasons shown on the S09 end card.
enum TripEndKind {
  /// User tapped Desci.
  user,

  /// Idle, timeout, or max duration.
  automatic,

  /// Permission revoked or GPS off.
  permission,

  /// Server abuse decision.
  abuse,

  /// Maintenance or auth failure.
  server,
}

/// Dependencies of the controller. All injected for tests.
class TripDeps {
  /// Creates controller dependencies.
  const TripDeps({
    required this.api,
    required this.gateway,
    required this.consentStore,
    required this.consentVersion,
    required this.locations,
    required this.clock,
    this.gnssReader,
  });

  /// Typed API client.
  final BusApi api;

  /// OS permission gateway.
  final PermissionGateway gateway;

  /// Local consent versioning.
  final ConsentStore consentStore;

  /// Current consent text version.
  final int consentVersion;

  /// Location service factory.
  final LocationService Function() locations;

  /// Clock for durations.
  final Clock clock;

  /// GNSS quality reader. Null production default uses the real native
  /// channel on Android and an empty stream elsewhere. Tests inject a
  /// fake so no platform channel is ever touched. See D69.
  final GnssQualityReader? gnssReader;
}

/// Controls one trip from consent to end states.
class TripController extends ChangeNotifier {
  /// Creates a controller. Starts in [TripIdle].
  TripController(this._deps) : _state = const TripIdle();

  final TripDeps _deps;

  /// Current machine state.
  TripState get state => _state;
  TripState _state;

  /// Line being shared, if any.
  int? get lineId => _lineId;
  int? _lineId;

  /// Human line label for the notification.
  String get lineLabel => _lineLabel;
  String _lineLabel = '';

  /// How the last trip ended, for the S09 card.
  TripEndKind? get endKind => _endKind;
  TripEndKind? _endKind;

  /// Human end reason for automatic ends.
  String? get endDetail => _endDetail;
  String? _endDetail;

  /// Trip start time in ms for the elapsed ticker.
  int? get startedAtMs => _startedAtMs;
  int? _startedAtMs;

  /// Why the last [startTrip] returned false. Null after a successful
  /// start. The share flow maps this to a user-facing message.
  StartFailure? get failReason => _failReason;
  StartFailure? _failReason;

  /// Server error code of the last failed start, if any (for example
  /// quota, maint, area, register). Shown in the progress details only,
  /// never with coordinates or tokens.
  String? get lastErrorCode => _lastErrorCode;
  String? _lastErrorCode;

  LocationService? _locations;
  StreamSubscription<TripFix>? _fixSub;
  PingClient? _ping;
  Timer? _autoEndTimer;
  String? _activeToken;
  TripSupervisor? _supervisor;
  SamplingMode _samplingMode = SamplingMode.waiting;
  bool _checking = false;

  /// Earliest ms for the next ping send, paced to the last server
  /// interval. Fixes arriving earlier are skipped; the next slot sends
  /// the latest fix. Without this the client pings on every position
  /// update, and fast web streams trip the server rate strikes (D29).
  int _nextPingAtMs = 0;

  /// True after [cancelStart]. Checked between start steps so the
  /// progress sheet Cancelar button stops the flow promptly.
  bool _cancelled = false;

  /// Requests cancellation of an in-flight [startTrip]. Stops local
  /// resources; the awaiting start observes the closed stream and
  /// returns false with [StartFailure.declined].
  void cancelStart() {
    _cancelled = true;
    _stopLocal();
  }

  /// True while the web page is hidden (foreground-only sharing).
  /// Fixes are dropped while hidden; the server timeout ends the trip
  /// if the page stays hidden. See PLAN.md 8.12.
  bool get isWebHidden => _webHidden;
  bool _webHidden = false;

  /// Marks the web page hidden or visible. Notifies listeners so the
  /// banner updates. No-op on repeated values, but a visible transition
  /// still records [hiddenForMs] and may flag a likely server timeout.
  void setWebHidden(bool hidden, {int? hiddenForMs}) {
    if (_disposed) {
      return;
    }
    if (hidden) {
      _webHiddenSinceMs ??= _deps.clock.nowMs();
      if (_webHidden) {
        return;
      }
      _webHidden = true;
      notifyListeners();
      return;
    }
    final int? since = _webHiddenSinceMs;
    final int hiddenMs =
        hiddenForMs ?? (since == null ? 0 : _deps.clock.nowMs() - since);
    _webHiddenSinceMs = null;
    if (tripInProgress(_state) && hiddenMs >= webTripTimeoutFallbackMs) {
      _webTimeoutLikely = true;
    }
    if (!_webHidden) {
      return;
    }
    _webHidden = false;
    notifyListeners();
  }

  /// Web gap recovery after the page becomes visible again. Clears the
  /// pause, then asks the location service for one fresh fix and a stream
  /// restart when it is dead or silent. The accepted fix flows through
  /// the normal paced ping path, so the server interval still wins.
  Future<void> recoverWebSharing({required int hiddenForMs}) async {
    if (_disposed) {
      return;
    }
    setWebHidden(false, hiddenForMs: hiddenForMs);
    if (!tripInProgress(_state)) {
      return;
    }
    await _locations?.recoverNow();
  }

  int? _webHiddenSinceMs;

  /// Set when the page returns after a hide long enough to outlive the
  /// server timeout. Consumed by the next ping outcome: success clears it,
  /// `gone` is shown as a timeout instead of reviving.
  bool _webTimeoutLikely = false;

  /// True while the RF16 walking prompt should be on screen.
  bool get walkingPromptVisible => _supervisor?.promptVisible ?? false;

  /// True while sends keep failing and only probes go out.
  bool get isOffline => activeRole(_state) == TripRole.offlineSaver;

  /// True while location services are off (stream paused, banner shown).
  bool get isPaused => _supervisor?.paused ?? false;

  /// True while the grant is approximate-only (Precise guidance shown,
  /// sends held). Read-only view of the supervisor flag. See D71.
  bool get isImprecise => _supervisor?.imprecise ?? false;

  /// Last successful ping in ms, null before the first success.
  /// Read-only view of the supervisor clock; never changes behavior.
  int? get lastSuccessMs => _supervisor?.lastSuccessMs;

  /// Last accepted fix accuracy in meters, null before the first fix.
  /// Read-only; recorded on the existing fix path.
  double? get lastAccuracyM => _lastAccuracyM;
  double? _lastAccuracyM;

  /// Last accepted fix battery bucket, null before the first fix.
  /// Read-only; recorded on the existing fix path.
  int? get lastBatteryPct => _lastBatteryPct;
  int? _lastBatteryPct;

  /// Last accepted fix charging flag. Read-only.
  bool get lastCharging => _lastCharging;
  bool _lastCharging = false;

  /// Last GNSS quality sample, null before the first one or off-trip.
  /// Read-only; drives the satellite subtitle on the trip screen.
  /// Signal quality only, never location. See D69.
  GnssQuality? get lastGnssQuality => _lastGnssQuality;
  GnssQuality? _lastGnssQuality;
  StreamSubscription<GnssQuality>? _gnssSub;

  /// Last accepted fix, kept to re-create the server trip if its record
  /// vanishes mid-trip. Memory only, like the accuracy above.
  TripFix? _lastFix;

  /// Whether this trip already survived one spurious `gone`. At most one
  /// revive per trip, so a genuinely dead record still ends the trip.
  bool _revivedOnce = false;

  /// True while a revive POST is in flight. Late duplicates of the
  /// outcome that triggered it are dropped, not finished.
  bool _reviving = false;

  /// True after the permission is revoked mid-trip (3 bad polls).
  /// Read-only view of the supervisor flag.
  bool get permissionRevoked => _supervisor?.permissionRevoked ?? false;

  /// False while OS location services are off. Read-only.
  bool get servicesOn => !isPaused;

  /// Groups the existing state into signals for the health model.
  /// Read-only; never changes behavior.
  SharingSignals sharingSignals(int nowMs) {
    final bool starting = _state is! TripActive && _state is! TripIdle;
    final bool ended = _state is TripIdle && _endKind != null;
    return SharingSignals(
      ended: ended,
      isStarting: starting,
      offline: isOffline,
      servicesOn: servicesOn,
      permissionGranted: !permissionRevoked,
      imprecise: isImprecise,
      nowMs: nowMs,
      accuracyM: _lastAccuracyM,
      lastSuccessMs: _supervisor?.lastSuccessMs,
      startedAtMs: _startedAtMs,
      batteryPct: _lastBatteryPct,
      charging: _lastCharging,
    );
  }

  /// Resolves the health model for [nowMs]. The result is memoized on
  /// identical inputs so ticker rebuilds do no extra work.
  SharingHealth sharingHealth(int nowMs) {
    final SharingSignals s = sharingSignals(nowMs);
    final SharingHealth? cached = _cachedHealth;
    if (cached != null &&
        _cachedSignals != null &&
        _sameSignals(_cachedSignals!, s)) {
      return cached;
    }
    final SharingHealth h = resolveSharingHealth(s);
    _cachedSignals = s;
    _cachedHealth = h;
    return h;
  }

  SharingSignals? _cachedSignals;
  SharingHealth? _cachedHealth;

  /// Compares two signal sets field by field.
  bool _sameSignals(SharingSignals a, SharingSignals b) {
    return a.ended == b.ended &&
        a.isStarting == b.isStarting &&
        a.offline == b.offline &&
        a.servicesOn == b.servicesOn &&
        a.permissionGranted == b.permissionGranted &&
        a.imprecise == b.imprecise &&
        a.accuracyM == b.accuracyM &&
        a.lastSuccessMs == b.lastSuccessMs &&
        a.startedAtMs == b.startedAtMs &&
        a.nowMs == b.nowMs &&
        a.batteryPct == b.batteryPct &&
        a.charging == b.charging;
  }

  /// Current sampling mode for tests and the location service.
  @visibleForTesting
  SamplingMode get samplingMode => _samplingMode;

  void _set(TripState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  /// Maps an API failure to the share-flow reason shown to the user.
  StartFailure _classify(AppFailure failure) {
    if (failure is NetworkFailure) {
      return StartFailure.offline;
    }
    if (failure is ServerFailure) {
      switch (failure.code) {
        case 'rate':
        case 'quota':
        case 'capacity':
        case 'maint':
          return StartFailure.busy;
        case 'area':
          return StartFailure.outsideArea;
      }
    }
    return StartFailure.failed;
  }

  /// Extracts a short error code for the progress details. Never carries
  /// coordinates, tokens, or messages with values.
  String _codeOf(AppFailure failure) {
    if (failure is NetworkFailure) {
      return 'offline';
    }
    if (failure is ServerFailure) {
      return failure.code;
    }
    return 'failed';
  }

  /// Starts a trip on [lineId]. Returns false when consent is declined.
  /// [firstFixTimeout] bounds the wait for the first accepted GPS fix;
  /// expiry sets [failReason] to [StartFailure.noGps]. [onPhase] reports
  /// phase transitions for the progress sheet; it never throws.
  Future<bool> startTrip({
    required int lineId,
    required String lineLabel,
    required Future<bool> Function() showConsent,
    required Future<void> Function() showPermissions,
    Duration firstFixTimeout = const Duration(seconds: 60),
    void Function(
      SharePhase phase,
      SharePhaseStatus status, {
      String? errorCode,
    })?
    onPhase,
  }) async {
    if (_state is! TripIdle) {
      // A start is already in flight or active (double-tap, retry
      // racing the sheet). Fresh attempts start from Idle only.
      _failReason = StartFailure.busy;
      return false;
    }
    _lineId = lineId;
    _lineLabel = lineLabel;
    _endKind = null;
    _endDetail = null;
    _failReason = null;
    _lastErrorCode = null;
    _cancelled = false;
    _nextPingAtMs = 0;
    _lastAccuracyM = null;
    _lastBatteryPct = null;
    _lastCharging = false;
    _lastFix = null;
    _revivedOnce = false;
    _reviving = false;
    _webHidden = false;
    _webHiddenSinceMs = null;
    _webTimeoutLikely = false;
    _cachedSignals = null;
    _cachedHealth = null;
    _supervisor = TripSupervisor(gateway: _deps.gateway);
    _samplingMode = SamplingMode.waiting;
    _set(tripReduce(_state, TripEvent.tapStart));

    void phase(SharePhase phase, SharePhaseStatus status, {String? errorCode}) {
      try {
        onPhase?.call(phase, status, errorCode: errorCode);
      } catch (_) {
        // Progress reporting never breaks the start flow.
      }
    }

    bool aborted() => _cancelled || _disposed;

    phase(SharePhase.consent, SharePhaseStatus.active);
    final ConsentResult consent = await ensureConsent(
      currentVersion: _deps.consentVersion,
      store: _deps.consentStore,
      showSheet: showConsent,
      postConsents: () async {
        final Result<String> reg = await _deps.api.ensureRegistered();
        if (reg is Err<String>) {
          return const Err<bool>(NetworkFailure('register failed'));
        }
        final Result<bool> posted = await _deps.api.postConsents(
          (reg as Ok<String>).value,
          _deps.consentVersion,
        );
        return posted;
      },
    );
    if (aborted()) {
      phase(SharePhase.consent, SharePhaseStatus.failed, errorCode: 'cancel');
      _failReason = StartFailure.declined;
      _set(tripReduce(_state, TripEvent.consentDeclined));
      return false;
    }
    if (consent == ConsentResult.declined) {
      phase(SharePhase.consent, SharePhaseStatus.failed, errorCode: 'declined');
      _failReason = StartFailure.declined;
      _set(tripReduce(_state, TripEvent.consentDeclined));
      return false;
    }
    // offlinePending continues like granted: local acceptance is stored
    // and the trip attempt still runs. The server consent guard answers
    // 403 when the record is truly missing, reported at the start phase.
    // Failing here would skip permission and GPS for users whose POST
    // merely raced a bad network.
    phase(SharePhase.consent, SharePhaseStatus.done);
    _set(tripReduce(_state, TripEvent.consentAccepted));

    phase(SharePhase.permission, SharePhaseStatus.active);
    await showPermissions();
    if (aborted()) {
      phase(
        SharePhase.permission,
        SharePhaseStatus.failed,
        errorCode: 'cancel',
      );
      _failReason = StartFailure.declined;
      _set(tripReduce(_state, TripEvent.permissionsDenied));
      return false;
    }
    final LocationPermissionState perm = await _deps.gateway.request();
    if (perm != LocationPermissionState.granted) {
      phase(
        SharePhase.permission,
        SharePhaseStatus.failed,
        errorCode: 'denied',
      );
      _failReason = StartFailure.permission;
      _set(tripReduce(_state, TripEvent.permissionsDenied));
      return false;
    }
    // Approximate-only grants report coarse fixes that never pass the
    // publish gate, so fail here with guidance instead of stalling 60 s
    // at "waiting for GPS". Fail-open on a broken check. See D67.
    bool precise = true;
    try {
      precise = await _deps.gateway.preciseAccuracy();
    } catch (_) {
      precise = true;
    }
    if (!precise) {
      phase(
        SharePhase.permission,
        SharePhaseStatus.failed,
        errorCode: 'imprecise',
      );
      _failReason = StartFailure.imprecise;
      _set(tripReduce(_state, TripEvent.permissionsDenied));
      return false;
    }
    phase(SharePhase.permission, SharePhaseStatus.done);
    _set(tripReduce(_state, TripEvent.permissionsGranted));

    phase(SharePhase.register, SharePhaseStatus.active);
    final Result<String> reg;
    try {
      reg = await _deps.api.ensureRegistered();
    } catch (_) {
      // The typed client returns Result; anything thrown is unexpected
      // transport trouble. Report it instead of failing silently.
      phase(SharePhase.register, SharePhaseStatus.failed, errorCode: 'offline');
      await _stopLocal();
      _failReason = StartFailure.offline;
      _set(const TripIdle());
      return false;
    }
    if (aborted()) {
      phase(SharePhase.register, SharePhaseStatus.failed, errorCode: 'cancel');
      await _stopLocal();
      _failReason = StartFailure.declined;
      _set(const TripIdle());
      return false;
    }
    if (reg is Err<String>) {
      final StartFailure reason = _classify(reg.failure);
      final String code = _codeOf(reg.failure);
      _lastErrorCode = code;
      phase(SharePhase.register, SharePhaseStatus.failed, errorCode: code);
      await _stopLocal();
      _failReason = reason;
      _set(const TripIdle());
      return false;
    }
    phase(SharePhase.register, SharePhaseStatus.done);
    final String token = (reg as Ok<String>).value;
    // Wait for the first accepted fix so POST /v1/trip carries real
    // coordinates inside the bbox. Single subscription: the run loop
    // reuses the same broadcast stream below.
    _locations = _deps.locations();
    final Stream<TripFix> stream = _locations!.fixes(
      mode: SamplingMode.waiting,
      lineLabel: _lineLabel,
    );
    phase(SharePhase.gps, SharePhaseStatus.active);
    // Anchor on the first good fix (at or under [firstFixGoodAccuracyM])
    // when one arrives inside the GPS window, else the best-seen
    // accepted fix. A lone coarse fix no longer anchors the vehicle when
    // a good one follows seconds later; the window bound is unchanged.
    TripFix? first;
    TripFix? best;
    final int gpsDeadlineMs =
        _deps.clock.nowMs() + firstFixTimeout.inMilliseconds;
    try {
      while (first == null) {
        final int remainingMs = gpsDeadlineMs - _deps.clock.nowMs();
        if (remainingMs <= 0) {
          break;
        }
        TripFix next;
        try {
          next = await stream.first.timeout(
            Duration(milliseconds: remainingMs),
          );
        } on TimeoutException {
          // Window elapsed with no further fix: fall through to the
          // best-seen fallback below.
          break;
        }
        if (best == null || next.accuracyM < best.accuracyM) {
          best = next;
        }
        if (next.accuracyM <= firstFixGoodAccuracyM) {
          first = next;
        }
      }
    } on StateError {
      // The stream closed without a fix: Cancelar or dispose.
      phase(SharePhase.gps, SharePhaseStatus.failed, errorCode: 'cancel');
      await _stopLocal();
      _failReason = StartFailure.declined;
      _set(const TripIdle());
      return false;
    }
    first ??= best;
    if (first == null) {
      phase(SharePhase.gps, SharePhaseStatus.failed, errorCode: 'gps-timeout');
      await _stopLocal();
      _failReason = StartFailure.noGps;
      _set(const TripIdle());
      return false;
    }
    if (aborted()) {
      phase(SharePhase.gps, SharePhaseStatus.failed, errorCode: 'cancel');
      await _stopLocal();
      _failReason = StartFailure.declined;
      _set(const TripIdle());
      return false;
    }
    phase(SharePhase.gps, SharePhaseStatus.done);
    phase(SharePhase.start, SharePhaseStatus.active);
    final Result<TripInstruction> started;
    try {
      started = await _deps.api.startTrip(
        token,
        lineId: lineId,
        lat: first.lat,
        lng: first.lng,
        accuracyM: first.accuracyM,
        batteryPct: first.batteryPct,
        charging: first.charging,
      );
    } catch (_) {
      phase(SharePhase.start, SharePhaseStatus.failed, errorCode: 'offline');
      await _stopLocal();
      _failReason = StartFailure.offline;
      _set(tripReduce(_state, TripEvent.startFailed));
      _set(const TripIdle());
      return false;
    }
    if (started is Err<TripInstruction>) {
      await _stopLocal();
      final AppFailure failure = started.failure;
      final String code = _codeOf(failure);
      _lastErrorCode = code;
      phase(SharePhase.start, SharePhaseStatus.failed, errorCode: code);
      _failReason = _classify(failure);
      if (failure is ServerFailure && failure.code == 'consent') {
        // Server never recorded our consent: forget the confirmation so
        // the next tap reposts before retrying the start.
        await _deps.consentStore.clearPosted();
      }
      _set(tripReduce(_state, TripEvent.startFailed));
      _set(const TripIdle());
      return false;
    }
    if (aborted()) {
      // Cancelar raced the create POST: the server record exists but the
      // rider already left. End it best-effort instead of opening a
      // zombie trip that never pings and never auto-ends (the supervisor
      // is gone, so the rounds early-return forever).
      phase(SharePhase.start, SharePhaseStatus.failed, errorCode: 'cancel');
      await _finish(token, TripEndKind.user, null);
      _failReason = StartFailure.declined;
      return false;
    }
    phase(SharePhase.start, SharePhaseStatus.done);
    _startedAtMs = _deps.clock.nowMs();
    _supervisor?.begin(_startedAtMs!);
    _set(tripReduce(_state, TripEvent.startConfirmed));
    final int firstIntervalS = (started as Ok<TripInstruction>).value.intervalS;
    _runLoop(token, stream, firstIntervalS);
    return true;
  }

  void _runLoop(String token, Stream<TripFix> stream, int firstIntervalS) {
    _activeToken = token;
    _tripGen++;
    _nextPingAtMs = _deps.clock.nowMs() + firstIntervalS * 1000;
    _ping = PingClient(
      send: (Map<String, dynamic> fix) async {
        final Result<TripInstruction> res = await _deps.api.pingTrip(
          token,
          seq: fix['seq'] as int,
          lat: fix['lat'] as double,
          lng: fix['lng'] as double,
          speedMps: fix['spd'] as double,
          heading: fix['hdg'] as double?,
          accuracyM: fix['acc'] as double,
          batteryPct: fix['bat'] as int,
          charging: fix['chg'] as bool,
          role: _serverRole(),
        );
        if (res is Err<TripInstruction>) {
          final AppFailure failure = res.failure;
          // Terminal record states surface as outcomes so the trip ends
          // (auth) or revives (gone); everything transient retries with
          // backoff. Collapsing them all to status 0 left trips stuck
          // offline forever on a deleted record.
          if (failure is ServerFailure && failure.code == 'gone') {
            return const PingReply(status: 404);
          }
          if (failure is ServerFailure && failure.code == 'auth') {
            return const PingReply(status: 401);
          }
          return const PingReply(status: 0);
        }
        final TripInstruction inst = (res as Ok<TripInstruction>).value;
        return PingReply(
          status: 200,
          role: inst.role,
          intervalS: inst.intervalS,
          end: inst.end,
        );
      },
      refreshToken: () async {
        await _deps.api.ensureRegistered();
      },
      random: Random.secure(),
      delay: (Duration d) => Future<void>.delayed(d),
    );
    _fixSub = stream.listen((TripFix fix) {
      if (_webHidden) {
        return;
      }
      // A fix accepted before a hidden period can sit in the stream queue
      // and surface after recovery. Do not publish a position that is
      // already past the freshness gate.
      if (_deps.clock.nowMs() - fix.acceptedAtMs > fixMaxAgeMs) {
        return;
      }
      // Paced to the server interval: faster streams (notably web
      // watchPosition) would otherwise ping per fix and collect rate
      // strikes. Skipped fixes are redundant by latest-wins anyway.
      _onFix(fix);
      // While the grant is approximate-only, fixes that pass the gate
      // are still too coarse to publish as a bus position, so they are
      // recorded for health but never sent. See D71.
      if ((_supervisor?.imprecise ?? false) ||
          _deps.clock.nowMs() < _nextPingAtMs) {
        return;
      }
      final int gen = _tripGen;
      _ping?.queue(_fixBody(fix), (PingOutcome o) {
        if (gen == _tripGen) {
          _onOutcome(token, o);
        }
      });
    });
    // Supervision cadence: thresholds are minutes-scale (5 min GPS-off,
    // 3-poll permission debounce), so 30 s keeps every guarantee while
    // cutting platform-channel wakeups 3x versus 10 s.
    _autoEndTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_checkAutoEnd(token));
    });
    // GNSS quality rides along for diagnosis only: it never gates a fix
    // and never reaches the server. Notifies only when the displayed
    // satellite count changes, so the 1 Hz native stream does not
    // rebuild the trip screen every second. See D69.
    _gnssSub = watchGnssQuality(reader: _deps.gnssReader)
        .listen((GnssQuality q) {
          if (_disposed) {
            return;
          }
          final int? prev = _lastGnssQuality?.satsUsed;
          _lastGnssQuality = q;
          if (prev != q.satsUsed) {
            notifyListeners();
          }
        });
  }

  void _onFix(TripFix fix) {
    _lastFix = fix;
    final TripSupervisor? supervisor = _supervisor;
    if (supervisor == null) {
      return;
    }
    _lastAccuracyM = fix.accuracyM;
    _lastBatteryPct = fix.batteryPct;
    _lastCharging = fix.charging;
    final bool hadPrompt = supervisor.promptVisible;
    supervisor.onFix(fix, _deps.clock.nowMs());
    if (supervisor.promptVisible != hadPrompt) {
      notifyListeners();
    }
  }

  String _serverRole() {
    final TripRole? role = activeRole(_state);
    switch (role) {
      case TripRole.leader:
        return 'L';
      case TripRole.follower:
        return 'F';
      case TripRole.waiting:
      case TripRole.offlineSaver:
      case null:
        return 'W';
    }
  }

  Map<String, dynamic> _fixBody(TripFix fix) {
    return <String, dynamic>{
      'seq': fix.seq,
      'lat': fix.lat,
      'lng': fix.lng,
      'spd': fix.speedMps,
      'hdg': fix.heading,
      'acc': fix.accuracyM,
      'bat': fix.batteryPct,
      'chg': fix.charging,
    };
  }

  /// Test-only: queues the last accepted fix for immediate send, bypassing
  /// the server-interval pacing slot. The button that calls this exists
  /// only behind the `FORCE_PING_BUTTON` dart-define (default false), so
  /// production builds never expose it. Returns false when no trip runs
  /// or no fix arrived yet. A tap with no newer fix resends the latest
  /// one, which the server answers as a duplicate without changing state,
  /// so the full HTTP path is still exercised. Do not spam it: the
  /// per-device ping bucket (30/min) still applies.
  bool forcePingNow() {
    final TripFix? fix = _lastFix;
    final PingClient? ping = _ping;
    final String? token = _activeToken;
    if (fix == null || ping == null || token == null) {
      return false;
    }
    if (!tripInProgress(_state)) {
      return false;
    }
    _nextPingAtMs = 0;
    final int gen = _tripGen;
    ping.queue(_fixBody(fix), (PingOutcome o) {
      if (gen == _tripGen) {
        _onOutcome(token, o);
      }
    });
    return true;
  }

  void _onOutcome(String token, PingOutcome outcome) {
    if (_disposed) {
      return;
    }
    final String? end = outcome.end;
    if (end != null) {
      if (end == 'gone' && _reviving) {
        // A revive is already re-creating the record; late duplicates of
        // the outcome that triggered it change nothing.
        return;
      }
      if (end == 'gone' && _webTimeoutLikely) {
        // The page returned after a hide long enough for the server
        // timeout. The record is gone, and reviving it with the last fix
        // would present a new trip as if sharing had continued.
        _webTimeoutLikely = false;
        unawaited(_finish(token, TripEndKind.automatic, 'timeout'));
        return;
      }
      if (end == 'gone' && !_revivedOnce) {
        final int? line = _lineId;
        final TripFix? fix = _lastFix;
        if (line != null && fix != null && tripInProgress(_state)) {
          // Our own late trip-end or a server restart can delete a live
          // trip's record, and the next ping 404s. Re-create it once
          // instead of dropping a healthy trip; anything else ends the
          // trip exactly like the original outcome.
          _revivedOnce = true;
          _reviving = true;
          unawaited(_revive(token, line, fix, end));
          return;
        }
      }
      void finish() async {
        await _finish(token, _kindFor(end), end);
      }

      finish();
      return;
    }
    _nextPingAtMs = _deps.clock.nowMs() + outcome.intervalS * 1000;
    _webTimeoutLikely = false;
    final TripSupervisor? supervisor = _supervisor;
    if (supervisor == null) {
      return;
    }
    supervisor.onPingSuccess(_deps.clock.nowMs());
    if (isOffline) {
      _set(tripReduce(_state, TripEvent.wentOnline));
    }
    if (outcome.role == 'L') {
      _set(tripReduce(_state, TripEvent.roleLeader));
    } else if (outcome.role == 'F') {
      _set(tripReduce(_state, TripEvent.roleFollower));
    }
    _applyRound(supervisor);
  }

  /// Re-creates the server trip after a spurious `gone`, at most once per
  /// trip. The ping loop keeps running meanwhile, so sharing never visibly
  /// stops on a won race. Any failure ends the trip like the outcome that
  /// triggered the revive. If the user ended the trip while the revive
  /// was in flight, the orphan record is cleaned up instead of adopted.
  Future<void> _revive(
    String token,
    int lineId,
    TripFix fix,
    String end,
  ) async {
    try {
      final Result<TripInstruction> res = await _deps.api.startTrip(
        token,
        lineId: lineId,
        lat: fix.lat,
        lng: fix.lng,
        accuracyM: fix.accuracyM,
        batteryPct: fix.batteryPct,
        charging: fix.charging,
        resume: true,
      );
      if (_disposed) {
        return;
      }
      if (!tripInProgress(_state)) {
        await _finish(token, TripEndKind.user, null);
        return;
      }
      if (res is Ok<TripInstruction>) {
        // New generation: pings sent while the record was gone return
        // stale 404s that must not touch the revived trip.
        _tripGen++;
        final TripInstruction inst = res.value;
        _onOutcome(
          token,
          PingOutcome(role: inst.role, intervalS: inst.intervalS),
        );
        return;
      }
      final AppFailure failure = (res as Err<TripInstruction>).failure;
      if (failure is ServerFailure && failure.code == 'consent') {
        await _deps.consentStore.clearPosted();
      }
      await _finish(token, _kindFor(end), end);
    } catch (_) {
      if (!_disposed) {
        await _finish(token, _kindFor(end), end);
      }
    } finally {
      _reviving = false;
    }
  }

  TripEndKind _kindFor(String end) {
    switch (end) {
      case 'idle':
      case 'timeout':
        return TripEndKind.automatic;
      case 'abuse':
        return TripEndKind.abuse;
      default:
        return TripEndKind.server;
    }
  }

  Future<void> _checkAutoEnd(String token) async {
    final TripSupervisor? supervisor = _supervisor;
    if (_disposed ||
        _checking ||
        _startedAtMs == null ||
        supervisor == null ||
        !tripInProgress(_state)) {
      return;
    }
    _checking = true;
    try {
      await supervisor.pollEnvironment(_deps.clock.nowMs());
      await _applyRound(supervisor, token: token);
    } finally {
      _checking = false;
    }
  }

  /// Applies one supervision round: ends, offline flips, sampling, prompt.
  Future<void> _applyRound(TripSupervisor supervisor, {String? token}) async {
    if (_startedAtMs == null || !tripInProgress(_state)) {
      return;
    }
    final bool hadPrompt = supervisor.promptVisible;
    final bool hadImprecise = supervisor.imprecise;
    final Supervision round = supervisor.evaluate(
      role: _serverRole(),
      failures: _ping?.consecutiveFailures ?? 0,
      wasOffline: isOffline,
      startedAtMs: _startedAtMs!,
      nowMs: _deps.clock.nowMs(),
    );
    final AutoEndReason? reason = round.endReason;
    if (reason != null && token != null) {
      final TripEndKind kind =
          reason == AutoEndReason.permissionRevoked ||
              reason == AutoEndReason.gpsOff
          ? TripEndKind.permission
          : TripEndKind.automatic;
      await _finish(token, kind, _detailFor(reason));
      return;
    }
    if (round.offline && !isOffline) {
      _set(tripReduce(_state, TripEvent.wentOffline));
    }
    final LocationService? locations = _locations;
    if (locations != null) {
      _samplingMode = locations.requestMode(round.wanted, _deps.clock.nowMs());
    }
    if (supervisor.promptVisible != hadPrompt ||
        supervisor.imprecise != hadImprecise) {
      notifyListeners();
    }
  }

  String _detailFor(AutoEndReason reason) {
    switch (reason) {
      case AutoEndReason.permissionRevoked:
        return 'permission';
      case AutoEndReason.gpsOff:
        return 'gps';
      case AutoEndReason.walkingTimeout:
        return 'walking';
      case AutoEndReason.maxDuration:
        return 'max';
    }
  }

  /// Runs one auto-end evaluation with the active trip token.
  /// Test hook: the periodic timer owns this in production.
  @visibleForTesting
  Future<void> checkAutoEndForTest() async {
    final String? token = _activeToken;
    if (token != null) {
      await _checkAutoEnd(token);
    }
  }

  /// Feeds one accepted fix through the slow-speed tracker. Test hook:
  /// production fixes arrive from the location stream.
  @visibleForTesting
  void onFixForTest(TripFix fix) {
    _onFix(fix);
  }

  /// RF16: the user confirms they are still on the bus. Hides the prompt
  /// and restarts the slow-speed clock for another 15 minutes. Ignored
  /// after dispose: the dialog can outlive the route.
  void confirmStillRiding() {
    if (_disposed) {
      return;
    }
    _supervisor?.confirmStillRiding();
    notifyListeners();
  }

  /// RF16: the user confirms they left the bus. Ends the trip as a user end.
  Future<void> confirmLeftBus() async {
    await endTrip();
  }

  /// Ends the trip now: stops the service, then best-effort server end.
  Future<void> endTrip() async {
    final String? token = await _token();
    _set(tripReduce(_state, TripEvent.tapEnd));
    await _stopLocal();
    if (token != null) {
      try {
        await _deps.api.endTrip(token).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Best effort only.
      }
    }
    _endKind = TripEndKind.user;
    _set(tripReduce(_state, TripEvent.endConfirmed));
  }

  Future<void> _finish(String token, TripEndKind kind, String? detail) async {
    await _stopLocal();
    try {
      await _deps.api.endTrip(token).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best effort only.
    }
    _endKind = kind;
    _endDetail = detail;
    if (_state is TripActive) {
      _set(tripReduce(_state, TripEvent.tapEnd));
    }
    _set(const TripIdle());
  }

  Future<void> _stopLocal() async {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    _activeToken = null;
    _tripGen++;
    _webHidden = false;
    _webHiddenSinceMs = null;
    _webTimeoutLikely = false;
    _supervisor?.reset();
    _supervisor = null;
    final StreamSubscription<TripFix>? sub = _fixSub;
    _fixSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    _locations?.stop();
    _locations = null;
    final StreamSubscription<GnssQuality>? gnss = _gnssSub;
    _gnssSub = null;
    _lastGnssQuality = null;
    if (gnss != null) {
      unawaited(gnss.cancel());
    }
    // Invalidate the pump first: a retry parked in backoff must not wake
    // up and apply a stale fix to the next trip's server record.
    _ping?.close();
    _ping = null;
  }

  Future<String?> _token() async {
    try {
      final Result<String> reg = await _deps.api.ensureRegistered();
      if (reg is Ok<String>) {
        return reg.value;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Whether dispose has run. Late ping outcomes and auto-end checks
  /// after the trip screen is gone are ignored instead of notifying.
  bool _disposed = false;

  /// Trip generation: bumped on every loop start and every local stop
  /// so a late outcome from a previous trip can never end the next one
  /// (the pump outlives _stopLocal across backoff delays).
  int _tripGen = 0;

  @override
  void dispose() {
    _disposed = true;
    // Full teardown: dispose must also stop the location stream and
    // foreground service, not just the fix subscription. The direct
    // cancel below stays: the linter only recognizes it in dispose.
    _autoEndTimer?.cancel();
    unawaited(_fixSub?.cancel());
    unawaited(_gnssSub?.cancel());
    unawaited(_stopLocal());
    super.dispose();
  }
}

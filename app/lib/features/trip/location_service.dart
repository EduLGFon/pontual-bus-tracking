// Location service producing filtered fixes. The foreground service with
// a persistent notification starts from the visible activity; swiping the
// app away ends the trip. Fixes are filtered client-side and re-checked
// server-side. See PLAN.md 8.6 and spike S1.
// PRIVACY: fixes are rounded before sending and never logged; see Log
// which has no coordinate API. Mocked fixes are rejected.
// ignore_for_file: prefer_initializing_formals - injected fakes keep
// stable public names while the fields stay private.
import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pontual/core/config/env.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/core/logging/log.dart';
import 'package:pontual/domain/trip/sampling_policy.dart';

/// Accepted area for fixes. Mirrors the server bbox.
const BBox fixArea = BBox(
  latMin: -19.05,
  latMax: -18.40,
  lngMin: -40.25,
  lngMax: -39.55,
);

/// Maximum fix age in milliseconds.
const int fixMaxAgeMs = 20000;

/// Fix accuracy at or above which the signal counts as degraded for the
/// downgrade guard. Well under the 60 m publish gate: this never drops
/// a fix, it only keeps the faster GPS stream a little longer so the
/// next good fix arrives sooner. See DECISIONS.md D64.
const double degradedAccuracyM = 40;

/// Downgrade guard in milliseconds while the last accepted fix is
/// degraded. Dropping from high accuracy to the balanced stream right
/// when fixes turn coarse powers down GPS exactly when it is needed
/// most; holding the high-accuracy stream up to 60 s costs a bounded
/// amount of battery for more chances at a sub-60 m fix. Offline saver
/// and paused keep the normal guard: with no uploads, faster GPS buys
/// nothing.
const int degradedHoldMs = 60 * 1000;

/// One accepted fix ready to send.
class TripFix {
  /// Creates a fix.
  const TripFix({
    required this.seq,
    required this.lat,
    required this.lng,
    required this.speedMps,
    required this.heading,
    required this.accuracyM,
    required this.batteryPct,
    required this.charging,
    required this.acceptedAtMs,
  });

  /// Sequence number per accepted fix.
  final int seq;

  /// Rounded latitude.
  final double lat;

  /// Rounded longitude.
  final double lng;

  /// Rounded speed.
  final double speedMps;

  /// Heading or null.
  final double? heading;

  /// Accuracy in meters.
  final double accuracyM;

  /// Battery level in 5 percent steps.
  final int batteryPct;

  /// Charging flag.
  final bool charging;

  /// When the filter accepted this fix, in milliseconds. Used to drop a
  /// fix that sat in the stream queue across a hidden period and would
  /// otherwise be published with a stale position after recovery.
  final int acceptedAtMs;
}

/// Raw position reading for the pure filter.
class RawFix {
  /// Creates a raw reading.
  const RawFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.isMocked,
    required this.timestampMs,
  });

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Accuracy in meters.
  final double accuracyM;

  /// Mock provider flag.
  final bool isMocked;

  /// Reading time in milliseconds.
  final int timestampMs;
}

/// Drops mocked, stale, inaccurate, or out-of-area fixes.
bool acceptFix(RawFix fix, int nowMs) => dropReason(fix, nowMs) == null;

/// Why a raw reading is dropped, or null when it is accepted. Reason
/// strings only, never coordinates. Used for debug logging so field
/// tests can tell an empty sky from a bad filter.
String? dropReason(RawFix fix, int nowMs) {
  if (fix.isMocked) {
    return 'mocked';
  }
  if (nowMs - fix.timestampMs > fixMaxAgeMs) {
    return 'stale';
  }
  if (fix.accuracyM > fixAccuracyMaxM || fix.accuracyM < 0) {
    return 'accuracy';
  }
  if (!fixArea.contains(fix.lat, fix.lng)) {
    return 'outside';
  }
  return null;
}

/// Clamps negative speeds to zero. Some chipsets report a negative speed
/// for an unknown fix, and the server rejects negatives.
double normalizeSpeed(double speedMps) =>
    speedMps < 0 ? 0 : (speedMps * 10).round() / 10;

/// Still threshold in m/s under which a GPS bearing is noise. Matches
/// the server still-tick threshold: below this the chip derives no
/// direction from motion, so the fix carries no heading instead of a
/// random one. The server holds position on null headings and widens
/// attach tolerance. See D66.
const double stillSpeedMaxMps = 0.5;

/// Folds a heading into the server range of 0 to 359 or null.
/// Geolocator can report 360 for north and negatives for unknown.
/// Bearings at standstill are noise, so they are nulled instead of
/// published.
double? normalizeHeading(double heading, double speedMps) {
  if (speedMps < stillSpeedMaxMps) {
    return null;
  }
  if (heading == 360) {
    return 0;
  }
  if (heading >= 0 && heading < 360) {
    return heading;
  }
  return null;
}

/// Rounds a coordinate to 5 decimals.
double round5(double v) => (v * 100000).round() / 100000;

/// Rounds battery to 5 percent steps.
int batteryBucket(int pct) => (pct ~/ 5) * 5;

/// Timeout for the visible-resume one-shot fix. The browser may leave a
/// getCurrentPosition request pending while the document is not visible;
/// the timeout keeps the trip recovery path bounded.
const Duration oneShotFixTimeout = Duration(seconds: 15);

/// Settings for the visible-resume one-shot. High accuracy is intentional:
/// the first fix after returning is the one that restores the vehicle on the
/// map, and no foreground notification is attached because this is a web
/// recovery path with no Android service of its own.
LocationSettings oneShotSettingsFor() => const LocationSettings(
  accuracy: LocationAccuracy.high,
  timeLimit: oneShotFixTimeout,
);

/// Location settings per sampling mode.
LocationSettings settingsFor(SamplingMode mode, String lineLabel) {
  // The notification is ongoing and persistent: the foreground service
  // must survive screen-off and background on OEM skins that aggressively
  // kill background work. setOngoing needs no extra permission and does
  // not request background location, wake locks, or exemptions.
  final ForegroundNotificationConfig notification =
      ForegroundNotificationConfig(
        notificationTitle: 'Compartilhando viagem - $lineLabel',
        notificationText: 'Toque para abrir ou encerrar',
        setOngoing: true,
      );
  switch (mode) {
    case SamplingMode.waiting:
      // High accuracy: the waiting phase must engage the GPS receiver so
      // the first fix is a real GPS fix (sub-30 m) instead of a coarse
      // network fix. Medium/balanced accuracy (PRIORITY_BALANCED_POWER)
      // can resolve on WiFi/cell towers, never turns on GPS (no GPS
      // indicator), and yields fixes above the 60 m gate, which made the
      // start stall the full 60 s window and then fail. The waiting window
      // is bounded (<= 60 s) and short-lived, so the battery cost of high
      // accuracy here is acceptable. See PLAN.md 8.6.
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.leaderMoving:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.leaderStill:
      // Owner directive: every role samples every 5 s. Balanced accuracy
      // keeps battery below the high-accuracy moving stream; only the
      // power modes (offline saver, paused) keep a slow cadence.
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.follower:
      // Balanced, not low power: follower fixes must pass the same 60 m
      // gate as leader fixes, and low power (cell/WiFi, often 50 m to
      // 1 km) starves followers exactly in weak-GPS areas where the
      // next handover needs them. Cadence matches every other role at
      // 5 s (owner directive). See D63.
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.offlineSaver:
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        intervalDuration: const Duration(seconds: 45),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.paused:
      // Keep the foreground service while paused (GPS off, permission
      // flap): dropping to a bare LocationSettings would release the
      // service and let the OS kill the process while waiting for GPS
      // to return. Low power with the same persistent notification.
      return AndroidSettings(
        accuracy: LocationAccuracy.low,
        intervalDuration: const Duration(seconds: 45),
        foregroundNotificationConfig: notification,
      );
  }
}

/// Forwards app lifecycle changes to one [LocationService]. Production only:
/// tests call [LocationService.handleLifecycle] directly so they need no
/// binding or observer setup.
class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this._service);

  final LocationService _service;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _service.handleLifecycle(state == AppLifecycleState.resumed);
  }
}

/// Produces filtered fixes for the active trip. Only TripController drives
/// this service. See PLAN.md 14.3.
class LocationService {
  /// Creates a service. Production uses geolocator and battery_plus.
  LocationService({
    required Stream<Position> Function(LocationSettings settings)
    positionStream,
    required Future<int> Function() batteryLevel,
    required Future<bool> Function() charging,
    required int Function() nowMs,
    Future<Position> Function(LocationSettings settings)? oneShotPosition,
  }) : _positionStream = positionStream,
       _batteryLevel = batteryLevel,
       _charging = charging,
       _nowMs = nowMs,
       _oneShotPosition = oneShotPosition;

  /// Production service backed by geolocator and battery_plus.
  factory LocationService.production() {
    final Battery battery = Battery();
    final LocationService service = LocationService(
      positionStream: (LocationSettings s) =>
          Geolocator.getPositionStream(locationSettings: s),
      batteryLevel: () =>
          battery.batteryLevel.timeout(const Duration(seconds: 3)),
      charging: () async {
        // One-shot read. onBatteryStateChanged.first waits for the next
        // change event instead and stalls every fix while the battery
        // state does not change.
        final BatteryState state = await battery.batteryState.timeout(
          const Duration(seconds: 3),
        );
        return state == BatteryState.charging;
      },
      nowMs: () => DateTime.now().millisecondsSinceEpoch,
      oneShotPosition: (LocationSettings s) =>
          Geolocator.getCurrentPosition(locationSettings: s),
    );
    final _LifecycleObserver observer = _LifecycleObserver(service);
    service._observer = observer;
    WidgetsBinding.instance.addObserver(observer);
    // An unknown lifecycle state counts as resumed: a start from a visible
    // activity is always allowed to create the foreground service.
    final AppLifecycleState? initial = WidgetsBinding.instance.lifecycleState;
    service.handleLifecycle(
      initial == null || initial == AppLifecycleState.resumed,
    );
    return service;
  }

  final Stream<Position> Function(LocationSettings settings) _positionStream;
  final Future<int> Function() _batteryLevel;
  final Future<bool> Function() _charging;
  final int Function() _nowMs;
  final Future<Position> Function(LocationSettings settings)? _oneShotPosition;

  StreamSubscription<Position>? _sub;

  /// True while the app is visible (resumed). Native stream recreation is
  /// never attempted while backgrounded: Android 14+ denies a foreground
  /// service start from the background, which would silently kill the trip.
  bool _appResumed = true;

  /// True when a stalled or dead stream asked for recreation while the app
  /// was backgrounded. Consumed by one [resumeRecovery] on the next resume.
  bool _pendingRestart = false;
  SamplingMode? _pendingMode;

  /// True when the deferred restart was a dead or stalled recovery rather
  /// than an intentional background mode switch. Only recoveries count
  /// towards the no-event dead-stream threshold.
  bool _pendingRecovery = false;

  /// One deferred warning per background episode: supervision rounds keep
  /// requesting the same deferral every 30 s and must not spam the log.
  bool _deferredLogged = false;

  /// True after this resume already ran its single recovery attempt. Reset
  /// on the next background transition so a resume never retries in a loop.
  bool _resumeRecoveryDone = false;

  /// Last native subscription creation, in milliseconds. Caps dead or
  /// silent restarts to one per stall window while the app is visible:
  /// each recreation stops and restarts the Android foreground service.
  int _lastRestartAtMs = 0;

  /// Consecutive recreations without any position event in between. Two
  /// mean the native stream is not recovering, so it is marked dead and the
  /// controller ends the trip visibly instead of restarting forever.
  int _restartsWithoutEvent = 0;

  /// Production lifecycle observer. Null in tests, which call
  /// [handleLifecycle] directly and never touch the widget binding.
  WidgetsBindingObserver? _observer;

  /// True once the OS-side position stream errored or closed (location
  /// services toggled off mid-trip, OEM kill). The fix stream stays open,
  /// but no fixes arrive until the position stream is recreated.
  bool _streamDead = false;
  int _seq = 0;
  int _lastChangeMs = 0;
  SamplingMode _mode = SamplingMode.waiting;
  String _lineLabel = '';
  int _lastBatteryPct = 100;
  bool _lastCharging = false;

  /// Battery reads are platform channels; cache them TTL so dropped or
  /// duplicate fixes do not each pay two Binder calls.
  static const int batteryCacheTtlMs = 60 * 1000;
  int? _lastBatteryReadMs;

  /// Silence without any position event that forces a position-stream
  /// restart even for the same mode. The OS can freeze GPS delivery
  /// without closing the stream (notably with the screen off on OEM
  /// skins), and no error ever marks it dead: without this the trip goes
  /// quiet until the server timeout ends it. 30 s matches the hysteresis
  /// window, so a frozen background stream recovers within ~30 s instead
  /// of a full minute of silence.
  static const int stallRestartMs = 30 * 1000;

  /// Last position event seen on the native stream, accepted or filtered,
  /// in milliseconds. Stall detection must use this instead of the last
  /// accepted fix: a stream that keeps delivering coarse fixes is alive,
  /// and recreating it cannot improve accuracy. It would only stop and
  /// restart the Android foreground service.
  int? _lastPositionAtMs;

  /// Effective silence window for [mode]. Slow modes legitimately go
  /// [intervalSForMode] seconds between fixes, so the fixed 30 s window
  /// would recreate the stream before the first fix of every slow cycle
  /// (offline saver and paused run at 45 s), leaving a foreground service
  /// that stops and restarts forever.
  int _stallWindowMs(SamplingMode mode) {
    final int cadenceMs = intervalSForMode(mode) * 1000;
    return cadenceMs > stallRestartMs
        ? cadenceMs + stallRestartMs
        : stallRestartMs;
  }

  /// Accuracy of the last accepted fix, null before the first one.
  /// Drives the degraded downgrade guard in [requestMode] only; it
  /// never drops a fix (the 60 m gate owns that).
  double? _lastAccuracyM;

  /// True while the app is visible. Read-only view for tests and callers.
  bool get appResumed => _appResumed;

  /// Notified on app lifecycle changes. TripController sets this to run one
  /// recovery attempt when the app comes back to the foreground.
  void Function(bool resumed)? onLifecycleChanged;

  /// Records the app lifecycle. Notifies [onLifecycleChanged] only when the
  /// value changes. Safe after [stop]: it only updates state.
  void handleLifecycle(bool resumed) {
    final bool changed = resumed != _appResumed;
    _appResumed = resumed;
    if (resumed) {
      _deferredLogged = false;
    } else {
      // A new background episode may defer another restart on resume.
      _resumeRecoveryDone = false;
    }
    if (changed) {
      onLifecycleChanged?.call(resumed);
    }
  }

  /// Starts emitting accepted fixes for [mode]. Recreates the stream when
  /// the policy switches modes, at most once per stall window for dead or
  /// silent streams. See [requestMode].
  /// Precondition: called from a resumed activity during trip start; native
  /// creation while backgrounded is deferred elsewhere.
  Stream<TripFix> fixes({
    required SamplingMode mode,
    required String lineLabel,
  }) {
    // ignore: close_sinks - owned by this service, closed in stop().
    final StreamController<TripFix> controller =
        StreamController<TripFix>.broadcast();
    final int nowMs = _nowMs();
    _controller = controller;
    _lineLabel = lineLabel;
    _pendingRestart = false;
    _pendingMode = null;
    _pendingRecovery = false;
    _deferredLogged = false;
    _resumeRecoveryDone = false;
    _restartsWithoutEvent = 0;
    _listen(mode, controller);
    _mode = mode;
    _lastChangeMs = nowMs;
    _lastRestartAtMs = nowMs;
    // No onCancel handler by design: TripController awaits stream.first
    // for the start fix, and cancelling the position stream when that
    // one-shot subscription ends would starve the run loop. Only stop()
    // ends the stream. See DECISIONS.md T34.
    return controller.stream;
  }

  void _listen(SamplingMode m, StreamController<TripFix> controller) {
    // Initial subscription only: no previous stream to cancel, so the
    // foreground service starts in one synchronous step. Recreations go
    // through [_relisten], which awaits the old cancellation first so the
    // native foreground service is not disabled after the new stream has
    // already started it (see DECISIONS.md note on mode-switch races).
    // A cancel on a stream that never started rejects with "No active
    // stream to cancel"; the handler keeps that PlatformException out of
    // FlutterError.onError.
    unawaited(_sub?.cancel().then((_) {}, onError: (_) {}));
    _sub = null;
    _streamDead = false;
    _lastPositionAtMs = _nowMs();
    _sub = _positionStream(settingsFor(m, _lineLabel)).listen(
      (Position p) => _emit(p, controller),
      onError: (Object e) {
        Log.w('position stream error', e.runtimeType.toString());
        // The OS closes the position stream when location services go
        // off. requestMode recreates it on the next supervision round.
        _streamDead = true;
      },
      onDone: () {
        _streamDead = true;
      },
    );
  }

  /// Marks a restart as pending instead of touching the native stream.
  /// Logs once per background episode so supervision rounds stay quiet.
  /// A dead or stalled stream keeps the stall message; an intentional mode
  /// change logs separately so field triage is not misled.
  void _deferRestart(SamplingMode mode, {required bool recovery}) {
    _pendingRestart = true;
    _pendingMode = mode;
    _pendingRecovery = recovery;
    if (_deferredLogged) {
      return;
    }
    _deferredLogged = true;
    if (recovery) {
      Log.w('position stream stalled', 'deferred');
    } else {
      Log.w('mode switch deferred', 'background');
    }
  }

  /// True when a dead or silent restart is allowed at [nowMs]. Each
  /// recreation stops and restarts the Android foreground service, so the
  /// foreground budget is one restart per stall window of [mode] (the mode
  /// being requested, not the old one, so a switch to a slow mode applies
  /// its longer window).
  bool _canRestart(SamplingMode mode, int nowMs) =>
      nowMs - _lastRestartAtMs >= _stallWindowMs(mode);

  /// The running native recreation, if any. A resume recovery and a
  /// supervision round can request a restart at the same time; both wait on
  /// this one future so cancel and listen never interleave.
  Future<void>? _relistenInFlight;

  /// Recreates the position stream, joining an in-flight recreation instead
  /// of starting a second one. The [recovery] flag separates dead or silent
  /// recoveries from intentional mode switches: only recoveries count
  /// towards the no-event dead-stream threshold.
  Future<void> _relisten(
    SamplingMode m,
    StreamController<TripFix> controller, {
    required bool recovery,
  }) {
    final Future<void>? inFlight = _relistenInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<void> work = _relistenNow(m, controller, recovery);
    _relistenInFlight = work;
    return work.whenComplete(() {
      if (identical(_relistenInFlight, work)) {
        _relistenInFlight = null;
      }
    });
  }

  Future<void> _relistenNow(
    SamplingMode m,
    StreamController<TripFix> controller,
    bool recovery,
  ) async {
    if (!_appResumed) {
      // Defense in depth: never start the native stream from the
      // background. Callers normally defer before reaching here.
      _deferRestart(m, recovery: recovery);
      return;
    }
    final StreamSubscription<Position>? old = _sub;
    _sub = null;
    if (old != null) {
      // Cancelling can stall indefinitely on some platforms (geolocator
      // foreground-service teardown) or in test fakes, which previously
      // froze supervision rounds and the trip screen. Bound the wait so
      // the new stream still starts; the old subscription is detached
      // either way. See DECISIONS.md note on mode-switch races.
      try {
        await old.cancel().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Best effort: proceed with the new subscription regardless.
      }
    }
    // stop() can run during the bounded cancel wait: it clears the
    // controller and subscription and ends the trip. Do not create a new
    // native subscription after that, or the foreground service leaks
    // past stop (the teardown gate does not cover this recreation).
    if (!identical(_controller, controller) ||
        controller.isClosed ||
        _sub != null) {
      return;
    }
    if (recovery) {
      // Only recovery restarts count: an intentional mode switch is not
      // evidence that the native stream stopped recovering.
      _restartsWithoutEvent += 1;
    }
    _streamDead = false;
    final int nowMs = _nowMs();
    _lastPositionAtMs = nowMs;
    _lastRestartAtMs = nowMs;
    _sub = _positionStream(settingsFor(m, _lineLabel)).listen(
      (Position p) => _emit(p, controller),
      onError: (Object e) {
        Log.w('position stream error', e.runtimeType.toString());
        _streamDead = true;
      },
      onDone: () {
        _streamDead = true;
      },
    );
    if (_restartsWithoutEvent >= 2) {
      // Two recoveries with no position event in between: the native
      // stream is not recovering. Report it dead so the controller ends
      // the trip visibly instead of recreating the foreground service in
      // a loop.
      _streamDead = true;
    }
  }

  /// Filters one position and emits it when accepted. Shared by the
  /// position stream and the visible-resume one-shot so both paths apply
  /// the same age, mock, accuracy, and area gates. Returns true only when
  /// a fix was added to an open stream.
  bool _emit(Position p, StreamController<TripFix> controller) {
    // Battery reads are platform channels that can stall for seconds in
    // the background: never block the fix on them. Emit immediately with
    // the last known bucket and refresh the cache in the background for
    // the next fix. The previous code awaited up to 3 s per fix before
    // sending, adding seconds to every ping.
    final RawFix raw = RawFix(
      lat: p.latitude,
      lng: p.longitude,
      accuracyM: p.accuracy,
      isMocked: p.isMocked,
      timestampMs: p.timestamp.millisecondsSinceEpoch,
    );
    final int atMs = _nowMs();
    // Any position event proves the OS stream is alive, even when the
    // filter drops it below. The stall watchdog must not recreate a
    // healthy stream just because every fix in a patch is too coarse.
    _lastPositionAtMs = atMs;
    // A position event also ends the consecutive-restart streak: the
    // native stream is delivering again.
    _restartsWithoutEvent = 0;
    final String? reason = dropReason(raw, atMs);
    if (reason != null) {
      Log.d('fix dropped', reason);
      return false;
    }
    if (controller.isClosed) {
      return false;
    }
    _seq += 1;
    final double speed = normalizeSpeed(p.speed);
    controller.add(
      TripFix(
        seq: _seq,
        lat: round5(raw.lat),
        lng: round5(raw.lng),
        speedMps: speed,
        heading: normalizeHeading(p.heading, speed),
        accuracyM: raw.accuracyM,
        batteryPct: batteryBucket(_lastBatteryPct),
        charging: _lastCharging,
        acceptedAtMs: atMs,
      ),
    );
    _lastAccuracyM = raw.accuracyM;
    final int? lastRead = _lastBatteryReadMs;
    if (lastRead == null || atMs - lastRead >= batteryCacheTtlMs) {
      // Reserve first: concurrent fixes share one refresh.
      _lastBatteryReadMs = atMs;
      unawaited(_refreshBattery());
    }
    return true;
  }

  /// Refreshes the cached battery bucket in the background. Failures keep
  /// the last known values; a stuck read never delays a fix.
  Future<void> _refreshBattery() async {
    try {
      // Parallel and bounded: a stuck battery read must never starve
      // location. Failures keep the last known values.
      final List<Object> parts = await Future.wait<Object>(<Future<Object>>[
        _batteryLevel().timeout(const Duration(seconds: 3)),
        _charging().timeout(const Duration(seconds: 3)),
      ]);
      final int level = (parts[0] as int).clamp(0, 100);
      final bool chg = parts[1] as bool;
      _lastBatteryPct = level;
      _lastCharging = chg;
    } catch (_) {
      Log.w('battery read failed', 'last kept');
    }
  }

  /// True when the position stream is dead or has gone silent past the
  /// stall window for its current sampling cadence. Silence counts even
  /// before the first fix: a start that never produces one is exactly the
  /// silent-trip failure this watchdog must catch. Used by both the
  /// supervision round and web recovery.
  bool _needsRestart(int nowMs) {
    if (_streamDead) {
      return true;
    }
    final int? eventAt = _lastPositionAtMs;
    final int windowMs = _stallWindowMs(_mode);
    return eventAt != null &&
        nowMs - eventAt > windowMs &&
        nowMs - _lastChangeMs >= windowMs;
  }

  /// Web gap recovery: restarts a dead or silent stream and requests one
  /// high-accuracy position through the normal filter. Never throws and
  /// never queues more than one one-shot at a time. Returns true when the
  /// one-shot fix was accepted; the regular stream remains the fallback.
  Future<bool> recoverNow() async {
    if (!_appResumed) {
      // Never ask for a location or recreate the service while backgrounded.
      return false;
    }
    final StreamController<TripFix>? controller = _controller;
    if (controller == null || controller.isClosed) {
      return false;
    }
    final int nowMs = _nowMs();
    if (_needsRestart(nowMs) && _canRestart(_mode, nowMs)) {
      Log.w('position stream stalled', 'restarting on visible');
      _lastChangeMs = nowMs;
      await _relisten(_mode, controller, recovery: true);
    }
    final Future<Position> Function(LocationSettings settings)? oneShot =
        _oneShotPosition;
    if (oneShot == null || _oneShotInFlight) {
      return false;
    }
    _oneShotInFlight = true;
    try {
      final Position p = await oneShot(oneShotSettingsFor())
          .timeout(oneShotFixTimeout);
      if (controller.isClosed) {
        return false;
      }
      return _emit(p, controller);
    } catch (e) {
      Log.w('one-shot position failed', e.runtimeType.toString());
      return false;
    } finally {
      _oneShotInFlight = false;
    }
  }

  bool _oneShotInFlight = false;

  /// Web and Android resume recovery. Runs at most once per resume: when a
  /// restart was deferred in the background (or the stream is dead or
  /// silent), it recreates the native stream exactly once with the pending
  /// or current mode. Android denies background foreground-service starts,
  /// so this is the only place a backgrounded stream returns to life. Safe
  /// after [stop] and before the first fix.
  Future<void> resumeRecovery() async {
    if (!_appResumed || _resumeRecoveryDone) {
      return;
    }
    _resumeRecoveryDone = true;
    final StreamController<TripFix>? controller = _controller;
    if (controller == null || controller.isClosed) {
      _pendingRestart = false;
      _pendingMode = null;
      return;
    }
    final int nowMs = _nowMs();
    final bool needs = _pendingRestart || _needsRestart(nowMs);
    final bool recovery = _pendingRestart ? _pendingRecovery : true;
    final SamplingMode mode = _pendingMode ?? _mode;
    _pendingRestart = false;
    _pendingMode = null;
    _pendingRecovery = false;
    if (!needs) {
      return;
    }
    _lastChangeMs = nowMs;
    await _relisten(mode, controller, recovery: recovery);
    _mode = mode;
  }

  /// Requests a mode switch honoring hysteresis for downgrades only.
  /// Recreates the underlying position stream when the mode actually
  /// changes so offline saver drops to low-power GPS. Upgrades to a faster
  /// cadence or to high accuracy bypass hysteresis: a fresh leader must
  /// reach high accuracy on the next fix, not after 30 s at the old
  /// waiting rate. While the last accepted fix is degraded (at or above
  /// [degradedAccuracyM]) role-driven downgrades wait [degradedHoldMs]
  /// instead of the normal window, so GPS stays powered through brief
  /// coarse patches; offline saver and paused keep the normal guard
  /// because faster GPS buys nothing with no uploads. A dead position
  /// stream is recreated at most once per stall window, even for the same
  /// mode and inside hysteresis: the trip has no fixes until it does, but
  /// each recreation restarts the Android foreground service. A silent
  /// stream (no position event for one full stall window of the current
  /// cadence) recreates too, under the same budget; some devices freeze
  /// delivery without ever erroring, while coarse fixes are still delivery
  /// and never trigger a restart. While backgrounded every recreation is
  /// deferred to [resumeRecovery]. Returns the active mode.
  Future<SamplingMode> requestMode(SamplingMode mode, int nowMs) async {
    final bool restartDead = _streamDead;
    final bool stalled = !restartDead && _needsRestart(nowMs);
    final bool restart = restartDead || stalled;
    if (mode == _mode && !restart) {
      return _mode;
    }
    final bool upgrade =
        intervalSForMode(mode) < intervalSForMode(_mode) ||
        (mode == SamplingMode.leaderMoving &&
            _mode != SamplingMode.leaderMoving);
    final double? lastAccuracy = _lastAccuracyM;
    final bool degradedHold =
        lastAccuracy != null &&
        lastAccuracy >= degradedAccuracyM &&
        mode != SamplingMode.offlineSaver &&
        mode != SamplingMode.paused;
    final int guardMs = degradedHold ? degradedHoldMs : streamHysteresisMs;
    if (!restart && !upgrade && nowMs - _lastChangeMs < guardMs) {
      return _mode;
    }
    if (!_appResumed) {
      // Android denies background foreground-service starts. Keep the
      // current native subscription untouched and recover once on resume.
      _deferRestart(mode, recovery: restart);
      return _mode;
    }
    if (restart && !_canRestart(mode, nowMs)) {
      // Foreground budget: at most one dead or silent restart per stall
      // window. The next supervision round retries once the window passes.
      return _mode;
    }
    if (stalled && !restartDead) {
      Log.w('position stream stalled', 'restarting');
    }
    _mode = mode;
    _lastChangeMs = nowMs;
    final StreamController<TripFix>? controller = _controller;
    if (controller != null && !controller.isClosed) {
      await _relisten(mode, controller, recovery: restart);
    }
    return _mode;
  }

  /// Current sequence for tests.
  @visibleForTesting
  int get debugSeq => _seq;

  StreamController<TripFix>? _controller;

  /// Process-wide teardown gate. Native geolocator teardown is async and
  /// shared: an unawaited cancel from trip N can land after trip N+1
  /// subscribes and flicker or kill the new foreground service. Every
  /// [stop] chains its native cancel into [_teardownGate]; every new trip
  /// awaits [awaitQuiescent] before subscribing, so teardown N always
  /// completes before subscription N+1 starts.
  static Future<void> _teardownGate = Future<void>.value();

  /// Waits until all pending native teardowns complete. Bounded by the
  /// caller with a timeout; never throws.
  static Future<void> awaitQuiescent() => _teardownGate;

  /// Resets the process-wide teardown gate. Test-only: unit and widget
  /// tests share one isolate, and an unawaited teardown from a previous
  /// test must never force the next test to burn its pump budget waiting
  /// on a fake that will never complete. Production never calls this.
  @visibleForTesting
  static void resetGateForTest() {
    _teardownGate = Future<void>.value();
  }

  /// True while a native position subscription is attached and the OS-side
  /// stream has not been declared dead. After a successful start this must
  /// stay true; a trip with no subscription is a silent trip and must fail
  /// visibly instead.
  bool get hasActiveSubscription => _sub != null && !_streamDead;

  /// True once at least one accepted fix was emitted. The startup handshake
  /// requires it so sharing never opens on a stream that never delivered.
  bool get hasProducedFix => _seq > 0;

  /// True when the stream is dead while the app is backgrounded. Recovery
  /// cannot start a foreground service from the background, so the
  /// controller waits for the resume instead of ending a healthy trip.
  bool get recoveryDeferred => !_appResumed && _streamDead;

  /// Effective silence window for the current mode, in milliseconds. Used
  /// by the controller to bound the startup no-fix invariant.
  int get stallWindowMs => _stallWindowMs(_mode);

  /// True while the fix broadcast is open for listeners.
  bool get hasOpenFixStream => _controller != null && !_controller!.isClosed;

  /// Stops the position stream, closes the fix stream, and detaches the
  /// production lifecycle observer. Never blocks the caller (awaiting
  /// native cancellations stalls widget test zones): the native cancel is
  /// bounded (2 s) and chained into the process-wide gate, so the next
  /// trip's [awaitQuiescent] still observes it. Returns immediately; the
  /// gate owns the async work.
  Future<void> stop() {
    final WidgetsBindingObserver? observer = _observer;
    _observer = null;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
    }
    _pendingRestart = false;
    _pendingMode = null;
    _pendingRecovery = false;
    final StreamSubscription<Position>? sub = _sub;
    _sub = null;
    final StreamController<TripFix>? c = _controller;
    _controller = null;
    Future<void> cancelWork = Future<void>.value();
    if (sub != null) {
      cancelWork = sub
          .cancel()
          .timeout(const Duration(seconds: 2))
          .then((_) {}, onError: (_) {});
    }
    // Chain first so a concurrent start observes the pending work even
    // though this stop returns immediately.
    final Future<void> gated = _teardownGate.then((_) => cancelWork);
    _teardownGate = gated.catchError((Object e, StackTrace s) {});
    unawaited(_teardownGate);
    if (c != null && !c.isClosed) {
      unawaited(c.close().then((_) {}, onError: (_) {}));
    }
    return Future<void>.value();
  }
}

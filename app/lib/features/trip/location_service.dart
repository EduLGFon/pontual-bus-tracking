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
import 'package:flutter/foundation.dart';
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
/// degraded. Dropping from high accuracy to a 45 s cadence right when
/// fixes turn coarse powers down GPS exactly when it is needed most;
/// holding the faster stream up to 60 s costs a bounded amount of
/// battery for more chances at a sub-60 m fix. Offline saver and paused
/// keep the normal guard: with no uploads, faster GPS buys nothing.
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

/// Folds a heading into the server range of 0 to 359 or null.
/// Geolocator can report 360 for north and negatives for unknown.
double? normalizeHeading(double heading) {
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
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
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
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: notification,
      );
    case SamplingMode.follower:
      // Balanced, not low power: follower fixes must pass the same 60 m
      // gate as leader fixes, and low power (cell/WiFi, often 50 m to
      // 1 km) starves followers exactly in weak-GPS areas where the
      // next handover needs them. Interval stays 45 s. See D63.
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        intervalDuration: const Duration(seconds: 45),
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
  }) : _positionStream = positionStream,
       _batteryLevel = batteryLevel,
       _charging = charging,
       _nowMs = nowMs;

  /// Production service backed by geolocator and battery_plus.
  factory LocationService.production() {
    final Battery battery = Battery();
    return LocationService(
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
    );
  }

  final Stream<Position> Function(LocationSettings settings) _positionStream;
  final Future<int> Function() _batteryLevel;
  final Future<bool> Function() _charging;
  final int Function() _nowMs;

  StreamSubscription<Position>? _sub;

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

  /// Silence without any accepted fix that forces a position-stream
  /// restart even for the same mode. The OS can freeze GPS delivery
  /// without closing the stream (notably with the screen off on OEM
  /// skins), and no error ever marks it dead: without this the trip goes
  /// quiet until the server timeout ends it. 30 s matches the hysteresis
  /// window, so a frozen background stream recovers within ~30 s instead
  /// of a full minute of silence.
  static const int stallRestartMs = 30 * 1000;
  int? _lastFixAtMs;

  /// Accuracy of the last accepted fix, null before the first one.
  /// Drives the degraded downgrade guard in [requestMode] only; it
  /// never drops a fix (the 60 m gate owns that).
  double? _lastAccuracyM;

  /// Starts emitting accepted fixes for [mode]. Recreates the stream when
  /// the policy switches modes, at most once per 30 seconds.
  Stream<TripFix> fixes({
    required SamplingMode mode,
    required String lineLabel,
  }) {
    // ignore: close_sinks - owned by this service, closed in stop().
    final StreamController<TripFix> controller =
        StreamController<TripFix>.broadcast();
    _controller = controller;
    _lineLabel = lineLabel;
    _listen(mode, controller);
    _mode = mode;
    _lastChangeMs = _nowMs();
    // No onCancel handler by design: TripController awaits stream.first
    // for the start fix, and cancelling the position stream when that
    // one-shot subscription ends would starve the run loop. Only stop()
    // ends the stream. See DECISIONS.md T34.
    return controller.stream;
  }

  void _listen(SamplingMode m, StreamController<TripFix> controller) {
    unawaited(_sub?.cancel());
    _streamDead = false;
    _sub = _positionStream(settingsFor(m, _lineLabel)).listen(
      (Position p) {
        // Battery reads are platform channels that can stall for seconds
        // in the background: never block the fix on them. Emit immediately
        // with the last known bucket and refresh the cache in the
        // background for the next fix. The previous code awaited up to
        // 3 s per fix before sending, adding seconds to every ping.
        final RawFix raw = RawFix(
          lat: p.latitude,
          lng: p.longitude,
          accuracyM: p.accuracy,
          isMocked: p.isMocked,
          timestampMs: p.timestamp.millisecondsSinceEpoch,
        );
        final int atMs = _nowMs();
        final String? reason = dropReason(raw, atMs);
        if (reason != null) {
          Log.d('fix dropped', reason);
          return;
        }
        _seq += 1;
        final int seq = _seq;
        final int level = _lastBatteryPct;
        final bool chg = _lastCharging;
        if (!controller.isClosed) {
          controller.add(
            TripFix(
              seq: seq,
              lat: round5(raw.lat),
              lng: round5(raw.lng),
              speedMps: normalizeSpeed(p.speed),
              heading: normalizeHeading(p.heading),
              accuracyM: raw.accuracyM,
              batteryPct: batteryBucket(level),
              charging: chg,
            ),
          );
          _lastFixAtMs = atMs;
          _lastAccuracyM = raw.accuracyM;
        }
        final int? lastRead = _lastBatteryReadMs;
        if (lastRead == null || atMs - lastRead >= batteryCacheTtlMs) {
          // Reserve first: concurrent fixes share one refresh.
          _lastBatteryReadMs = atMs;
          unawaited(_refreshBattery());
        }
      },
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
  /// stream recreates immediately, even for the same mode and inside
  /// hysteresis: the trip has no fixes until it does. A silent stream
  /// (fixes flowed, then nothing for [stallRestartMs]) recreates too, at
  /// most once per stall window: some devices freeze delivery without
  /// ever erroring. Returns the active mode.
  SamplingMode requestMode(SamplingMode mode, int nowMs) {
    final bool restartDead = _streamDead;
    final int? fixAt = _lastFixAtMs;
    final bool stalled =
        _seq > 0 &&
        fixAt != null &&
        nowMs - fixAt > stallRestartMs &&
        nowMs - _lastChangeMs >= stallRestartMs;
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
    if (stalled && !restartDead) {
      Log.w('position stream stalled', 'restarting');
    }
    _mode = mode;
    _lastChangeMs = nowMs;
    final StreamController<TripFix>? controller = _controller;
    if (controller != null && !controller.isClosed) {
      _listen(mode, controller);
    }
    return _mode;
  }

  /// Current sequence for tests.
  @visibleForTesting
  int get debugSeq => _seq;

  StreamController<TripFix>? _controller;

  /// Stops the position stream and closes the fix stream. Fire and
  /// forget by design: awaiting cancellations can stall test zones, and
  /// nothing after a stop needs their results.
  void stop() {
    final StreamSubscription<Position>? sub = _sub;
    _sub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    final StreamController<TripFix>? c = _controller;
    _controller = null;
    if (c != null && !c.isClosed) {
      unawaited(c.close());
    }
  }
}

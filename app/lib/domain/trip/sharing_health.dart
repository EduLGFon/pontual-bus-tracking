// Sharing health: one pure model for the trip screen rows, banner, and
// live indicator. The UI renders short tile values from the codes and
// shows at most one banner for the primary issue, so the same sentence
// never appears twice. Time is a parameter; the caller owns ticks.
// Thresholds new to the project live here and are listed in
// docs/ui/sharing-screen-redesign.md.
library;

/// Severity of one tile. Green is OK only; tips are neutral.
enum SharingLevel {
  /// Healthy state.
  ok,

  /// Degraded but sharing-related, shown amber.
  warn,

  /// Sharing cannot continue this way, shown red.
  error,

  /// Starting or ended, shown without status color.
  neutral,
}

/// Overall sharing state driving the live indicator.
enum SharingOverall {
  /// Trip is starting, first position not sent yet.
  starting,

  /// Positions are flowing.
  live,

  /// Sharing is paused (offline, GPS problem, low battery guard).
  paused,

  /// Trip ended.
  ended,
}

/// Short connection tile values (one or two words).
enum ConnectionValue {
  /// Connected.
  connected,

  /// Transient, for example during startup grace.
  reconnecting,

  /// Steady offline.
  offline,
}

/// Short GPS tile values.
enum GpsValue {
  /// Fix flowing with good accuracy.
  good,

  /// Fix flowing but coarse.
  weak,

  /// No fix yet or fix lost.
  noFix,

  /// Location services off.
  off,

  /// OS permission revoked.
  noPermission,

  /// Waiting for the first fix during startup.
  searching,
}

/// Short device tile values. The device tile describes the phone only,
// never connectivity.
enum DeviceValue {
  /// Screen held on, battery fine.
  screenOn,

  /// Low battery or saver risk.
  lowBattery,
}

/// Primary issue driving the single banner. Priority order is the enum
/// order after [none]: permission, location off, offline, GPS, battery.
enum SharingIssue {
  /// No banner.
  none,

  /// Permission revoked during the trip.
  permission,

  /// Location services off.
  locationOff,

  /// Sends failing.
  offline,

  /// Weak GPS accuracy.
  gpsWeak,

  /// No GPS fix.
  gpsNoFix,

  /// Low battery while unplugged.
  lowBattery,
}

/// Accuracy above this is weak. Fixes above 60 m are dropped by the
/// location filter (`fixAccuracyMaxM`); this tier is new.
const double weakGpsAccuracyM = 30;

/// Last successful send older than this while online is marked stale
/// (amber, text unchanged). New threshold.
const int staleSendAfterMs = 45 * 1000;

/// Battery at or below this while unplugged is low. New threshold.
const int lowBatteryPct = 15;

/// Startup grace: no offline banner during the first seconds. New.
const int startupGraceMs = 3000;

/// Signals the health model reads. All values already exist in the
/// controller or supervisor; this type only groups them.
class SharingSignals {
  /// Creates signals for one evaluation.
  const SharingSignals({
    required this.ended,
    required this.isStarting,
    required this.offline,
    required this.servicesOn,
    required this.permissionGranted,
    required this.nowMs,
    this.accuracyM,
    this.lastSuccessMs,
    this.startedAtMs,
    this.batteryPct,
    this.charging = false,
  });

  /// True when the trip already ended.
  final bool ended;

  /// True while the start is still in flight.
  final bool isStarting;

  /// True while only probes go out (supervisor offline rule).
  final bool offline;

  /// False while OS location services are off.
  final bool servicesOn;

  /// False after the permission is revoked mid-trip.
  final bool permissionGranted;

  /// Last accepted fix accuracy in meters, null when unknown.
  final double? accuracyM;

  /// Last successful ping in milliseconds, null when never sent.
  final int? lastSuccessMs;

  /// Trip start in milliseconds, null before confirmation.
  final int? startedAtMs;

  /// Now in milliseconds.
  final int nowMs;

  /// Last known battery bucket, null when unknown.
  final int? batteryPct;

  /// True while charging.
  final bool charging;
}

/// Resolved health for one render.
class SharingHealth {
  /// Creates resolved health.
  const SharingHealth({
    required this.connectionLevel,
    required this.connectionValue,
    required this.gpsLevel,
    required this.gpsValue,
    required this.deviceLevel,
    required this.deviceValue,
    required this.issue,
    required this.overall,
    required this.lastSendStale,
  });

  /// Severity of the connection tile.
  final SharingLevel connectionLevel;

  /// Short connection value.
  final ConnectionValue connectionValue;

  /// Severity of the GPS tile.
  final SharingLevel gpsLevel;

  /// Short GPS value.
  final GpsValue gpsValue;

  /// Severity of the device tile.
  final SharingLevel deviceLevel;

  /// Short device value.
  final DeviceValue deviceValue;

  /// Primary issue, [SharingIssue.none] when no banner is needed.
  final SharingIssue issue;

  /// Overall sharing state.
  final SharingOverall overall;

  /// True when the last send is stale while online.
  final bool lastSendStale;
}

/// Resolves tile values, the primary issue, and the overall state.
SharingHealth resolveSharingHealth(SharingSignals s) {
  if (s.ended) {
    return const SharingHealth(
      connectionLevel: SharingLevel.neutral,
      connectionValue: ConnectionValue.connected,
      gpsLevel: SharingLevel.neutral,
      gpsValue: GpsValue.good,
      deviceLevel: SharingLevel.neutral,
      deviceValue: DeviceValue.screenOn,
      issue: SharingIssue.none,
      overall: SharingOverall.ended,
      lastSendStale: false,
    );
  }
  if (!s.permissionGranted) {
    return SharingHealth(
      connectionLevel: SharingLevel.warn,
      connectionValue: s.offline
          ? ConnectionValue.offline
          : ConnectionValue.connected,
      gpsLevel: SharingLevel.error,
      gpsValue: GpsValue.noPermission,
      deviceLevel: _deviceOf(s),
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.permission,
      overall: SharingOverall.paused,
      lastSendStale: false,
    );
  }
  if (!s.servicesOn) {
    return SharingHealth(
      connectionLevel: SharingLevel.warn,
      connectionValue: s.offline
          ? ConnectionValue.offline
          : ConnectionValue.connected,
      gpsLevel: SharingLevel.error,
      gpsValue: GpsValue.off,
      deviceLevel: _deviceOf(s),
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.locationOff,
      overall: SharingOverall.paused,
      lastSendStale: false,
    );
  }
  final bool inGrace =
      s.startedAtMs != null && s.nowMs - s.startedAtMs! < startupGraceMs;
  if (s.isStarting || (inGrace && s.lastSuccessMs == null)) {
    return SharingHealth(
      connectionLevel: SharingLevel.neutral,
      connectionValue: ConnectionValue.reconnecting,
      gpsLevel: SharingLevel.neutral,
      gpsValue: GpsValue.searching,
      deviceLevel: SharingLevel.neutral,
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.none,
      overall: SharingOverall.starting,
      lastSendStale: false,
    );
  }
  if (s.offline) {
    return SharingHealth(
      connectionLevel: SharingLevel.warn,
      connectionValue: ConnectionValue.offline,
      gpsLevel: _gpsLevelOnline(s),
      gpsValue: _gpsValueOnline(s),
      deviceLevel: _deviceOf(s),
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.offline,
      overall: SharingOverall.paused,
      lastSendStale: false,
    );
  }
  final GpsValue gps = _gpsValueOnline(s);
  final SharingLevel gpsLevel = _gpsLevelOnline(s);
  final bool stale =
      s.lastSuccessMs != null && s.nowMs - s.lastSuccessMs! > staleSendAfterMs;
  if (gps == GpsValue.weak) {
    return SharingHealth(
      connectionLevel: SharingLevel.ok,
      connectionValue: ConnectionValue.connected,
      gpsLevel: SharingLevel.warn,
      gpsValue: GpsValue.weak,
      deviceLevel: _deviceOf(s),
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.gpsWeak,
      overall: SharingOverall.paused,
      lastSendStale: stale,
    );
  }
  if (gps == GpsValue.noFix) {
    return SharingHealth(
      connectionLevel: SharingLevel.ok,
      connectionValue: ConnectionValue.connected,
      gpsLevel: SharingLevel.warn,
      gpsValue: GpsValue.noFix,
      deviceLevel: _deviceOf(s),
      deviceValue: _deviceValueOf(s),
      issue: SharingIssue.gpsNoFix,
      overall: SharingOverall.paused,
      lastSendStale: stale,
    );
  }
  if (_deviceValueOf(s) == DeviceValue.lowBattery) {
    return SharingHealth(
      connectionLevel: SharingLevel.ok,
      connectionValue: ConnectionValue.connected,
      gpsLevel: SharingLevel.ok,
      gpsValue: GpsValue.good,
      deviceLevel: SharingLevel.warn,
      deviceValue: DeviceValue.lowBattery,
      issue: SharingIssue.lowBattery,
      overall: SharingOverall.paused,
      lastSendStale: stale,
    );
  }
  return SharingHealth(
    connectionLevel: SharingLevel.ok,
    connectionValue: ConnectionValue.connected,
    gpsLevel: gpsLevel,
    gpsValue: gps,
    deviceLevel: SharingLevel.ok,
    deviceValue: DeviceValue.screenOn,
    issue: SharingIssue.none,
    overall: SharingOverall.live,
    lastSendStale: stale,
  );
}

GpsValue _gpsValueOnline(SharingSignals s) {
  final double? acc = s.accuracyM;
  if (acc == null) {
    return s.lastSuccessMs == null ? GpsValue.noFix : GpsValue.good;
  }
  if (acc > weakGpsAccuracyM) {
    return GpsValue.weak;
  }
  return GpsValue.good;
}

SharingLevel _gpsLevelOnline(SharingSignals s) {
  return switch (_gpsValueOnline(s)) {
    GpsValue.good => SharingLevel.ok,
    GpsValue.weak => SharingLevel.warn,
    GpsValue.noFix => SharingLevel.warn,
    GpsValue.off => SharingLevel.error,
    GpsValue.noPermission => SharingLevel.error,
    GpsValue.searching => SharingLevel.neutral,
  };
}

DeviceValue _deviceValueOf(SharingSignals s) {
  final int? pct = s.batteryPct;
  if (pct != null && pct <= lowBatteryPct && !s.charging) {
    return DeviceValue.lowBattery;
  }
  return DeviceValue.screenOn;
}

SharingLevel _deviceOf(SharingSignals s) {
  return _deviceValueOf(s) == DeviceValue.lowBattery
      ? SharingLevel.warn
      : SharingLevel.ok;
}

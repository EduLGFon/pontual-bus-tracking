// Explicit, one-shot, foreground-only viewer location for the line screen.
// The line screen makes one automatic attempt on mount, so the OS or
// browser prompt is the only first-use permission UI. After that the rider
// can retry from the prompt or error card, and the line screen refreshes
// the fix on the existing 5 s vehicle tick. One fix at a time, reused for
// 5 minutes inside the app session, dropped when cleared. Keep-alive on
// purpose: the card and the map share the same state without re-asking
// permission.
// PRIVACY: the fix lives only in this provider's memory. Never log the
// coordinates, the accuracy, or any identifier, never persist it, never
// send it. The ETA request carries only line id and stop id.
// See ARCHITECTURE.md PRV01 and docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/data/prefs/viewer_location_auto_request.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/platform/android/permission_gateway.dart';
import 'package:pontual/ui/util/platform.dart';

/// How long a fix is reused before a new one is needed.
const Duration viewerFixTtl = Duration(minutes: 5);

/// Background viewer-fix refresh interval on the existing vehicle tick.
const Duration viewerFixRefreshInterval = Duration(seconds: 60);

/// Web accuracy gate in meters. The browser cannot promise a precise fix,
/// so the bar is coarser than on native.
const double viewerWebAccuracyMaxM = 200;

/// Native accuracy gate in meters. A coarse native fix would mislead the
/// nearest-stop snap, so the flow asks for precise location instead.
const double viewerNativeAccuracyMaxM = 120;

/// States of the explicit viewer-locating flow.
enum ViewerFixStatus {
  /// Nothing requested yet.
  idle,

  /// Permission or fix in flight.
  requesting,

  /// A usable fix is in state.
  ready,

  /// Permission denied, retryable.
  denied,

  /// Permission permanently denied: only settings help.
  blocked,

  /// Granted but approximate, or the fix was too coarse.
  imprecise,

  /// Device location services are off.
  servicesOff,

  /// The fix landed outside the served area.
  outsideArea,

  /// The fix failed or timed out.
  error,
}

/// Outcome of one explicit locating attempt.
@immutable
class ViewerFixState {
  /// Creates the state.
  const ViewerFixState({
    this.status = ViewerFixStatus.idle,
    this.position,
    this.accuracyM,
    this.at,
  });

  /// Where the flow stands.
  final ViewerFixStatus status;

  /// Viewer position, or null until and after success.
  final LatLng? position;

  /// Fix accuracy in meters, or null.
  final double? accuracyM;

  /// When the fix landed, for the 5-minute freshness rule.
  final DateTime? at;
}

/// Permission gateway for this flow. Faked in tests.
final Provider<PermissionGateway> viewerPermissionGatewayProvider =
    Provider<PermissionGateway>(
      (Ref ref) => const GeolocatorPermissionGateway(),
    );

/// One-shot high-accuracy position reader. Never called before the
/// explicit tap. Overridable in tests; no stream, no watcher.
final Provider<Future<Position> Function()> viewerPositionReaderProvider =
    Provider<Future<Position> Function()>((Ref ref) {
      return () => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(const Duration(seconds: 20));
    });

/// Clock seam for the freshness rule and the refresh throttle.
final Provider<DateTime Function()> viewerNowProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Store for the one automatic attempt flag. Faked or pre-seeded in tests.
final Provider<ViewerLocationAutoRequestStore> viewerAutoRequestStoreProvider =
    Provider<ViewerLocationAutoRequestStore>(
      (Ref ref) => const ViewerLocationAutoRequestStore(),
    );

/// Web seam for tests: kIsWeb is a compile-time constant, so the browser
/// flow cannot be reached in VM tests without this indirection.
final Provider<bool> viewerIsWebProvider = Provider<bool>(
  (Ref ref) => PlatformInfo.isWeb,
);

/// True when the existing vehicle tick should refresh the viewer fix.
///
/// Only a held fix is refreshed; a denied or failed first attempt waits
/// for an explicit tap. [lastAttempt] throttles retries even when the
/// previous fix is older than [viewerFixRefreshInterval].
bool viewerFixRefreshDue({
  required ViewerFixState fix,
  required DateTime now,
  DateTime? lastAttempt,
}) {
  if (fix.status != ViewerFixStatus.ready || fix.position == null) {
    return false;
  }
  final DateTime? baseline = lastAttempt ?? fix.at;
  if (baseline == null) {
    return false;
  }
  return now.difference(baseline) >= viewerFixRefreshInterval;
}

/// Owns the explicit locating flow.
class ViewerFixController extends Notifier<ViewerFixState> {
  @override
  ViewerFixState build() => const ViewerFixState();

  /// True once this controller tried the automatic path in this session.
  bool _autoAttempted = false;

  /// Makes the one automatic attempt per install on line-screen mount.
  ///
  /// The stored flag survives restarts, so a denial is never followed by
  /// another automatic prompt. The rider can still retry explicitly from
  /// the prompt or error card. Does nothing when a fix is already known.
  Future<void> requestAutomatic() async {
    if (_autoAttempted) {
      return;
    }
    _autoAttempted = true;
    final ViewerLocationAutoRequestStore store = ref.read(
      viewerAutoRequestStoreProvider,
    );
    bool already;
    try {
      already = await store.requested();
    } on Object {
      // Without the flag, fail closed: never risk a second automatic
      // permission prompt. The explicit card remains available.
      return;
    }
    if (already) {
      // A later automatic attempt may still reuse an existing grant. Native
      // checks silently, so a denied grant never prompts again; the web
      // cannot query permission first, so it attempts a reuse and only
      // prompts when the browser requires it.
      if (state.status != ViewerFixStatus.idle) {
        return;
      }
      await request(auto: !ref.read(viewerIsWebProvider));
      return;
    }
    if (state.status != ViewerFixStatus.idle) {
      return;
    }
    try {
      await request();
    } finally {
      try {
        await store.markRequested();
      } on Object {
        // A missing flag write is not worth blocking the fix for.
      }
    }
  }

  /// Requests permission (native) or the browser fix (web). Never throws.
  ///
  /// Returns immediately when a fresh fix is already held, unless
  /// [force] refreshes. A second call while requesting is a no-op.
  ///
  /// A refresh keeps the previous position and status visible while it is
  /// in flight. When [silent] is true, a failed refresh restores the
  /// previous state instead of exposing an error, so the dot and the card
  /// survive a transient GPS or permission failure. [auto] marks a later
  /// automatic attempt: a missing grant is reported instead of prompting.
  /// Returns true when a fix attempt actually started.
  Future<bool> request({
    bool force = false,
    bool silent = false,
    bool auto = false,
  }) async {
    final ViewerFixState current = state;
    if (current.status == ViewerFixStatus.requesting) {
      return false;
    }
    final DateTime now = ref.read(viewerNowProvider)();
    final DateTime? at = current.at;
    if (!force &&
        current.status == ViewerFixStatus.ready &&
        current.position != null &&
        at != null &&
        now.difference(at) < viewerFixTtl) {
      return false;
    }
    final ViewerFixState? previous = silent && current.position != null
        ? current
        : null;
    state = current.position != null
        ? ViewerFixState(
            status: ViewerFixStatus.requesting,
            position: current.position,
            accuracyM: current.accuracyM,
            at: current.at,
          )
        : const ViewerFixState(status: ViewerFixStatus.requesting);
    try {
      await _fix(auto: auto);
      if (silent && state.status != ViewerFixStatus.ready) {
        state = previous ?? state;
      }
    } on Object {
      state = previous ?? const ViewerFixState(status: ViewerFixStatus.error);
    }
    return true;
  }

  /// Drops the fix and returns the flow to idle.
  void clear() {
    state = const ViewerFixState();
  }

  Future<void> _fix({required bool auto}) async {
    if (ref.read(viewerIsWebProvider)) {
      // Web flow: the browser prompt is the position call itself, so
      // there is nothing to pre-check without triggering it. The prompt
      // fires automatically once, then again only from an explicit tap.
      await _read(web: true);
      return;
    }
    await _native(auto: auto);
  }

  Future<void> _native({required bool auto}) async {
    final PermissionGateway gateway = ref.read(viewerPermissionGatewayProvider);
    final bool servicesOn = await gateway.servicesOn();
    if (!servicesOn) {
      state = const ViewerFixState(status: ViewerFixStatus.servicesOff);
      return;
    }
    LocationPermissionState permission = await gateway.check();
    if (permission == LocationPermissionState.denied) {
      if (auto) {
        state = const ViewerFixState(status: ViewerFixStatus.denied);
        return;
      }
      permission = await gateway.request();
    }
    switch (permission) {
      case LocationPermissionState.permanentlyDenied:
        state = const ViewerFixState(status: ViewerFixStatus.blocked);
        return;
      case LocationPermissionState.denied:
        state = const ViewerFixState(status: ViewerFixStatus.denied);
        return;
      case LocationPermissionState.granted:
        break;
    }
    final bool precise = await gateway.preciseAccuracy();
    if (!precise) {
      state = const ViewerFixState(status: ViewerFixStatus.imprecise);
      return;
    }
    await _read(web: false);
  }

  Future<void> _read({required bool web}) async {
    try {
      final Position position = await ref.read(viewerPositionReaderProvider)();
      final double maxAccuracyM = web
          ? viewerWebAccuracyMaxM
          : viewerNativeAccuracyMaxM;
      if (position.accuracy > maxAccuracyM) {
        state = const ViewerFixState(status: ViewerFixStatus.imprecise);
        return;
      }
      final LatLng point = LatLng(position.latitude, position.longitude);
      if (!mapBounds.contains(point)) {
        state = const ViewerFixState(status: ViewerFixStatus.outsideArea);
        return;
      }
      state = ViewerFixState(
        status: ViewerFixStatus.ready,
        position: point,
        accuracyM: position.accuracy,
        at: ref.read(viewerNowProvider)(),
      );
    } on TimeoutException {
      // A fix this slow would mislead more than it helps. PRIVACY: no
      // detail of the failed attempt is reported anywhere.
      state = const ViewerFixState(status: ViewerFixStatus.error);
    } on Object {
      // Web: the browser prompt is the request, so any failure here is a
      // denial or a blocked context. Native: a reader failure is retryable
      // through the same card, so it reports as error.
      state = web
          ? const ViewerFixState(status: ViewerFixStatus.denied)
          : const ViewerFixState(status: ViewerFixStatus.error);
    }
  }
}

/// Owns the flow state.
final NotifierProvider<ViewerFixController, ViewerFixState> viewerFixProvider =
    NotifierProvider<ViewerFixController, ViewerFixState>(
      ViewerFixController.new,
    );

/// Compatibility seam for the line screen and the reports adapter: viewer
/// position, or null while the fix is not ready. Derives from the
/// explicit flow above and never asks for a position on its own.
// PRIVACY: this value is not logged and not sent anywhere.
final FutureProvider<LatLng?> viewerLocationProvider = FutureProvider<LatLng?>(
  (Ref ref) async => ref.watch(viewerFixProvider).position,
);

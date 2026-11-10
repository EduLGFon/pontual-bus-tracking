// Explicit, one-shot, foreground-only viewer location for the line screen.
// Nothing asks for a position on mount: the flow starts only from the
// "Usar minha localização" tap in the my-stop sheet, which is also where
// the privacy copy lives. One fix at a time, reused for 5 minutes inside
// the app session, dropped when cleared. Keep-alive on purpose: the card
// and the map share the same state without re-asking permission.
// PRIVACY: the fix lives only in this provider's memory. Never log the
// coordinates, the accuracy, or any identifier, never persist it, never
// send it. The ETA request carries only line id and stop id.
// See PLAN.md PRV01 and docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/platform/android/permission_gateway.dart';
import 'package:pontual/ui/util/platform.dart';

/// How long a fix is reused before a new one is needed.
const Duration viewerFixTtl = Duration(minutes: 5);

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

/// Clock seam for the freshness rule.
final Provider<DateTime Function()> viewerNowProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Web seam for tests: kIsWeb is a compile-time constant, so the browser
/// flow cannot be reached in VM tests without this indirection.
final Provider<bool> viewerIsWebProvider = Provider<bool>(
  (Ref ref) => PlatformInfo.isWeb,
);

/// Owns the explicit locating flow. Only `request` starts anything.
class ViewerFixController extends Notifier<ViewerFixState> {
  @override
  ViewerFixState build() => const ViewerFixState();

  /// Requests permission (native) or the browser fix (web). Never throws.
  ///
  /// Returns immediately when a fresh fix is already held, unless
  /// [force] refreshes. A second call while requesting is a no-op.
  Future<void> request({bool force = false}) async {
    final ViewerFixState current = state;
    if (current.status == ViewerFixStatus.requesting) {
      return;
    }
    final DateTime? at = current.at;
    if (!force &&
        current.status == ViewerFixStatus.ready &&
        current.position != null &&
        at != null &&
        ref.read(viewerNowProvider)().difference(at) < viewerFixTtl) {
      return;
    }
    state = const ViewerFixState(status: ViewerFixStatus.requesting);
    await _fix();
  }

  /// Drops the fix and returns the flow to idle.
  void clear() {
    state = const ViewerFixState();
  }

  Future<void> _fix() async {
    if (ref.read(viewerIsWebProvider)) {
      // Web flow: the browser prompt is the position call itself, so
      // there is nothing to pre-check without triggering it. The prompt
      // must only ever fire from the explicit user tap.
      await _read(web: true);
      return;
    }
    await _native();
  }

  Future<void> _native() async {
    final PermissionGateway gateway = ref.read(viewerPermissionGatewayProvider);
    final bool servicesOn = await gateway.servicesOn();
    if (!servicesOn) {
      state = const ViewerFixState(status: ViewerFixStatus.servicesOff);
      return;
    }
    LocationPermissionState permission = await gateway.check();
    if (permission == LocationPermissionState.denied) {
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

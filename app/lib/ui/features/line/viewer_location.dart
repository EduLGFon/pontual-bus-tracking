// Viewer position for the line map. One low-power fix per screen mount,
// used only to frame the camera and draw the viewer dot. It never leaves
// the device: only trip pings reach the server, and only while a trip runs.
// PRIVACY: this value is never logged and never sent anywhere.
// See PLAN.md PRV01 and docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/platform/android/permission_gateway.dart';
import 'package:pontual/ui/adapters/local_stores.dart';

/// Viewer accuracy gate in meters. Coarser than this, the dot would
/// mislead more than it helps, so the map falls back to the city center.
const double viewerAccuracyMaxM = 200;

/// Viewer position, or null when unknown. Null covers every case that must
/// not move the camera: permission not already granted (never prompted
/// here), data saver on (the power-saving mode), lookup failure or timeout,
/// a coarse fix, and a fix outside the served area.
///
/// The lookup uses medium accuracy with a generous timeout: it runs once
/// per mount and the map never waits for it, so a slow first fix still
/// lands as a dot instead of leaving the rider at the city fallback.
///
/// Auto-disposed: the lookup re-runs per screen mount, so a moved viewer
/// never sees a stale app-lifetime dot.
final FutureProvider<LatLng?> viewerLocationProvider =
    FutureProvider.autoDispose<LatLng?>((Ref ref) async {
      if (ref.watch(settingsProvider).dataSaver) {
        return null;
      }
      try {
        // On web there is no "already granted" state we can query without
        // prompting: the position call itself is the permission request, and
        // dev-tools location overrides only take effect once it runs. On
        // native we keep the no-prompt behaviour (viewer dot only when
        // permission is already granted).
        if (!kIsWeb) {
          final LocationPermissionState state =
              await const GeolocatorPermissionGateway().check();
          if (state != LocationPermissionState.granted) {
            return null;
          }
        }
        final Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(const Duration(seconds: 20));
        // Web overrides often report a coarse or zero accuracy; do not drop
        // the dot there on accuracy alone.
        if (!kIsWeb && position.accuracy > viewerAccuracyMaxM) {
          return null;
        }
        final LatLng point = LatLng(position.latitude, position.longitude);
        if (!mapBounds.contains(point)) {
          return null;
        }
        return point;
      } on Object {
        // No position, no prompt, no error surface: the map stands on the
        // city center instead.
        return null;
      }
    });

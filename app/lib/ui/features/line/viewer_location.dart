// Viewer position for the line map. One low-power fix per screen mount,
// used only to frame the camera and draw the viewer dot. It never leaves
// the device: only trip pings reach the server, and only while a trip runs.
// PRIVACY: this value is never logged and never sent anywhere.
// See PLAN.md PRV01 and docs/ui/UI_SPEC.md 7.5.
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
final FutureProvider<LatLng?> viewerLocationProvider =
    FutureProvider<LatLng?>((Ref ref) async {
      if (ref.watch(settingsProvider).dataSaver) {
        return null;
      }
      try {
        final LocationPermissionState state =
            await const GeolocatorPermissionGateway().check();
        if (state != LocationPermissionState.granted) {
          return null;
        }
        final Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        ).timeout(const Duration(seconds: 10));
        if (position.accuracy > viewerAccuracyMaxM) {
          return null;
        }
        final LatLng point = LatLng(
          position.latitude,
          position.longitude,
        );
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

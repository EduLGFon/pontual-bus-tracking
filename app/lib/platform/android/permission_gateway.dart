// Geolocator-backed permission gateway. Implements the T30 interface
// with the real OS APIs. See PLAN.md S07 and spike S1.
import 'package:geolocator/geolocator.dart';
import 'package:pontual/features/trip/permission_sheet.dart';

/// Permission gateway using geolocator.
class GeolocatorPermissionGateway implements PermissionGateway {
  /// Creates the gateway.
  const GeolocatorPermissionGateway();

  @override
  Future<LocationPermissionState> check() async {
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionState> request() async {
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<bool> servicesOn() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<bool> preciseAccuracy() async {
    try {
      // Web has no accuracy-status API and throws UnimplementedError;
      // browsers grant precise-or-nothing, so fail-open is correct there.
      return await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.precise;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  LocationPermissionState _map(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
    }
  }
}

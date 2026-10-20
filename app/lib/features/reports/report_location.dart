// One-shot location for a report. Reads the device once, converts the fix
// to a ~150 m cell on-device, and returns only the cell id. Exact
// coordinates never leave this function.
// PRIVACY: never log the fix or the cell.
// See DECISIONS.md#D83.
import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:pontual/domain/reporting/report_area.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/platform/android/permission_gateway.dart';

/// Maximum accuracy accepted for a report area, in meters.
const double reportLocationAccuracyMaxM = 150;

/// One raw fix, kept inside this module and discarded after the cell id.
typedef ReportFix = ({double lat, double lng, double accuracyM});

/// Why a report area could not be produced.
enum ReportLocationFailure {
  /// Device location services are off.
  servicesOff,

  /// Permission was denied and can be asked again.
  denied,

  /// Permission is blocked; only settings help.
  blocked,

  /// The fix took too long.
  timeout,

  /// The fix was coarser than [reportLocationAccuracyMaxM].
  imprecise,

  /// The computed cell is outside the served area.
  outsideArea,

  /// Any other geolocation failure.
  unknown,
}

/// Result of a report-area read.
sealed class ReportAreaResult {
  const ReportAreaResult();
}

/// A coarse cell was produced.
class ReportAreaOk extends ReportAreaResult {
  /// Creates a successful result.
  const ReportAreaOk(this.areaId);

  /// Coarse ~150 m grid cell.
  final String areaId;
}

/// No area was produced.
class ReportAreaError extends ReportAreaResult {
  /// Creates a failure result.
  const ReportAreaError(this.reason);

  /// Why the read failed.
  final ReportLocationFailure reason;
}

/// Reads a fix and converts it to a report cell.
class ReportLocationService {
  /// Creates the service. Both dependencies are injectable for tests.
  ReportLocationService({
    this.gateway = const GeolocatorPermissionGateway(),
    this.readFix = geolocatorReportFix,
  });

  /// Permission gateway.
  final PermissionGateway gateway;

  /// One-shot fix reader. Returns exact coordinates only inside this call.
  final Future<ReportFix> Function() readFix;

  /// Acquires one fix and returns a cell, or a typed failure.
  Future<ReportAreaResult> acquire() async {
    try {
      if (!await gateway.servicesOn()) {
        return const ReportAreaError(ReportLocationFailure.servicesOff);
      }
      LocationPermissionState state = await gateway.check();
      if (state == LocationPermissionState.denied) {
        state = await gateway.request();
      }
      if (state == LocationPermissionState.permanentlyDenied) {
        return const ReportAreaError(ReportLocationFailure.blocked);
      }
      if (state != LocationPermissionState.granted) {
        return const ReportAreaError(ReportLocationFailure.denied);
      }
      final ReportFix fix = await readFix().timeout(
        const Duration(seconds: 22),
      );
      if (fix.accuracyM > reportLocationAccuracyMaxM) {
        return const ReportAreaError(ReportLocationFailure.imprecise);
      }
      final String areaId = reportAreaOf(fix.lat, fix.lng);
      if (!isReportAreaInServedBBox(areaId)) {
        return const ReportAreaError(ReportLocationFailure.outsideArea);
      }
      return ReportAreaOk(areaId);
    } on TimeoutException {
      return const ReportAreaError(ReportLocationFailure.timeout);
    } on LocationServiceDisabledException {
      return const ReportAreaError(ReportLocationFailure.servicesOff);
    } on PermissionDeniedException {
      return const ReportAreaError(ReportLocationFailure.denied);
    } on Object {
      return const ReportAreaError(ReportLocationFailure.unknown);
    }
  }
}

/// Real one-shot fix. Medium accuracy is enough for a 150 m cell.
Future<ReportFix> geolocatorReportFix() async {
  final Position position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 15),
    ),
  );
  return (
    lat: position.latitude,
    lng: position.longitude,
    accuracyM: position.accuracy,
  );
}

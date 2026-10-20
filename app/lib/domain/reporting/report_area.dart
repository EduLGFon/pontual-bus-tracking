// Coarse report areas. The app converts a one-shot location fix into a
// ~150 m grid cell and sends only the cell id; exact coordinates never
// leave the device. Mirrors server/src/domain/areas.ts.
// PRIVACY: never log coordinates or cell ids.
// See DECISIONS.md#D83.
import 'dart:math' as math;

/// Cell edge in meters.
const double reportCellM = 150;

/// Reference latitude for the longitude step. Fixed for the served area.
const double reportRefLat = -18.7;

const double _latStep = reportCellM / 111320;
final double _lngStep =
    reportCellM / (111320 * math.cos(reportRefLat * math.pi / 180));
final RegExp _areaId = RegExp(r'^g(\d{1,6})_(\d{1,7})$');

/// Approximate center of one cell.
class ReportAreaCenter {
  /// Creates a cell center.
  const ReportAreaCenter({required this.lat, required this.lng});

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;
}

/// Grid cell id for a coordinate. Mirrors the server implementation.
String reportAreaOf(double lat, double lng) {
  final int latIdx = ((lat + 90) / _latStep).floor();
  final int lngIdx = ((lng + 180) / _lngStep).floor();
  return 'g${latIdx}_$lngIdx';
}

/// Decodes a cell id to its approximate center, or null when malformed.
ReportAreaCenter? reportAreaCenterOf(String areaId) {
  final RegExpMatch? match = _areaId.firstMatch(areaId);
  if (match == null) return null;
  final int? latIdx = int.tryParse(match.group(1)!);
  final int? lngIdx = int.tryParse(match.group(2)!);
  if (latIdx == null || lngIdx == null) return null;
  return ReportAreaCenter(
    lat: (latIdx + 0.5) * _latStep - 90,
    lng: (lngIdx + 0.5) * _lngStep - 180,
  );
}

/// True when [areaId] is a well-formed grid cell.
bool isValidReportArea(String areaId) => _areaId.hasMatch(areaId);

/// Served-area minimum latitude. Mirrors the server engine bbox.
const double servedLatMin = -19.05;

/// Served-area maximum latitude. Mirrors the server engine bbox.
const double servedLatMax = -18.40;

/// Served-area minimum longitude. Mirrors the server engine bbox.
const double servedLngMin = -40.25;

/// Served-area maximum longitude. Mirrors the server engine bbox.
const double servedLngMax = -39.55;

/// True when the cell center is inside the served area, with one cell of
/// margin. Mirrors server/src/domain/areas.ts.
bool isReportAreaInServedBBox(String areaId) {
  final ReportAreaCenter? center = reportAreaCenterOf(areaId);
  if (center == null) return false;
  return center.lat >= servedLatMin - _latStep &&
      center.lat <= servedLatMax + _latStep &&
      center.lng >= servedLngMin - _lngStep &&
      center.lng <= servedLngMax + _lngStep;
}

/// Approximate distance from a point to the cell center, in meters.
double? reportAreaDistanceM(String areaId, double lat, double lng) {
  final ReportAreaCenter? center = reportAreaCenterOf(areaId);
  if (center == null) return null;
  const double rad = math.pi / 180;
  final double dLat = (center.lat - lat) * rad;
  final double dLng = (center.lng - lng) * rad;
  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat * rad) *
          math.cos(center.lat * rad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * 6371000 * math.asin(math.sqrt(a));
}

// Pure geographic helpers. Units carry suffixes. Mirrors the server engine
// (server/src/domain/geo.ts) and the data route tool; kept in sync by
// round-trip tests.
import 'dart:math' as math;

/// Mean earth radius in meters.
const double earthRadiusM = 6371000;

/// Degrees latitude per meter of meridian arc.
const double degPerMeterLat = 1 / 111320;

/// Haversine distance in meters between two points.
double distM(double lat1, double lng1, double lat2, double lng2) {
  const double rad = math.pi / 180;
  final double dLat = (lat2 - lat1) * rad;
  final double dLng = (lng2 - lng1) * rad;
  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * rad) *
          math.cos(lat2 * rad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(a));
}

/// Bounding box in degrees.
class BBox {
  /// Creates a bounding box.
  const BBox({
    required this.latMin,
    required this.latMax,
    required this.lngMin,
    required this.lngMax,
  });

  /// Minimum latitude.
  final double latMin;

  /// Maximum latitude.
  final double latMax;

  /// Minimum longitude.
  final double lngMin;

  /// Maximum longitude.
  final double lngMax;

  /// True when the point is inside the box.
  bool contains(double lat, double lng) {
    return lat >= latMin && lat <= latMax && lng >= lngMin && lng <= lngMax;
  }
}

/// Decodes a Google encoded polyline at [precision] decimals.
///
/// Uses only arithmetic (no bitwise shifts): Dart bitwise operators are
/// 32-bit on dart2js, which corrupts large deltas. This form decodes
/// identically on the VM, wasm, and plain JavaScript.
List<LatLng> decodePolyline(String text, [int precision = 5]) {
  final double factor = math.pow(10, precision).toDouble();
  final List<LatLng> points = <LatLng>[];
  int lat = 0;
  int lng = 0;
  int i = 0;

  int readDelta() {
    int delta = 0;
    int multiplier = 1;
    int b;
    do {
      b = text.codeUnitAt(i++) - 63;
      delta += (b % 32) * multiplier;
      multiplier *= 32;
    } while (b >= 32);
    return delta.isOdd ? -(delta ~/ 2) - 1 : delta ~/ 2;
  }

  while (i < text.length) {
    lat += readDelta();
    lng += readDelta();
    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

/// Immutable latitude/longitude pair in degrees.
class LatLng {
  /// Creates a coordinate pair.
  const LatLng(this.lat, this.lng);

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;
}

/// Dead reckoning for stale vehicles (mirrors server geo.predict).
/// Heading is degrees clockwise from north. Null heading, no speed or
/// no age keeps the last fix. Pure, anonymous, no history.
LatLng predictPosition(
  double lat,
  double lng,
  double? headingDeg,
  double speedMps,
  int ageS,
) {
  if (headingDeg == null || speedMps <= 0 || ageS <= 0) {
    return LatLng(lat, lng);
  }
  const double degPerM = 1 / 111320;
  final double headingRad = headingDeg * math.pi / 180;
  final double d = speedMps * ageS;
  final double lat2 = lat + d * math.cos(headingRad) * degPerM;
  final double lng2 =
      lng + d * math.sin(headingRad) * degPerM / math.cos(lat * math.pi / 180);
  return LatLng(lat2, lng2);
}

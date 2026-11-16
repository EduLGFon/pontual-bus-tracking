// De-identified global stop points shared by every line. Pure Dart, no
// Flutter imports. Parsed defensively: unknown keys and missing optional
// fields never crash. See the /v1/stops and /v1/stops/<id>/arrivals
// contracts.
//
// Stop ids are opaque strings and are never parsed or interpreted.

int _intOf(Object? raw) => raw is num ? raw.toInt() : 0;

double _doubleOf(Object? raw) => raw is num ? raw.toDouble() : 0;

List<dynamic> _listOf(Object? raw) =>
    raw is List<dynamic> ? raw : const <dynamic>[];

// Service-area bounding box used by the learning server. A stop outside
// it (or at null island) is malformed data, not a real marker.
const double _minLat = -19.05;
const double _maxLat = -18.40;
const double _minLng = -40.25;
const double _maxLng = -39.55;

/// One line that serves a global stop, plus the member stop id used by
/// that line's own learned data.
class StopLineRef {
  /// Creates a stop line reference.
  const StopLineRef({
    required this.lineId,
    required this.direction,
    required this.stopId,
  });

  /// Stable line id.
  final int lineId;

  /// Travel direction (0 or 1).
  final int direction;

  /// Member stop id for that line, opaque.
  final String stopId;

  /// Parses a reference defensively.
  factory StopLineRef.fromJson(Map<String, dynamic> json) {
    final Object? lineRaw = json['l'] ?? json['line'] ?? json['lineId'];
    final Object? dirRaw = json['d'] ?? json['direction'];
    final Object? stopRaw = json['s'] ?? json['stop'] ?? json['stopId'];
    return StopLineRef(
      lineId: _intOf(lineRaw),
      direction: _intOf(dirRaw),
      stopId: stopRaw is String ? stopRaw : (stopRaw?.toString() ?? ''),
    );
  }
}

/// A global bus stop known to the learning subsystem.
class GlobalStop {
  /// Creates a global stop.
  const GlobalStop({
    required this.id,
    required this.lat,
    required this.lng,
    this.radiusM = 30,
    this.passes = 0,
    this.name,
    this.lines = const <StopLineRef>[],
  });

  /// Opaque stop id, never parsed.
  final String id;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Cluster radius in meters.
  final double radiusM;

  /// Number of passes contributing to this stop.
  final int passes;

  /// Posted name, null when unmapped.
  final String? name;

  /// Lines serving this stop.
  final List<StopLineRef> lines;

  /// True when the stop can be placed on the service-area map.
  bool get isValid =>
      id.isNotEmpty &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= _minLat &&
      lat <= _maxLat &&
      lng >= _minLng &&
      lng <= _maxLng;

  /// Parses a global stop defensively.
  factory GlobalStop.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLines = _listOf(json['lines']);
    final List<StopLineRef> lines = <StopLineRef>[];
    for (final dynamic e in rawLines) {
      if (e is Map) {
        try {
          lines.add(StopLineRef.fromJson(e.cast<String, dynamic>()));
        } on Object {
          // Skip malformed entries; never crash on bad data.
        }
      }
    }
    final Object? radiusRaw = json['r'] ?? json['radiusM'] ?? json['radius'];
    final Object? passesRaw = json['n'] ?? json['passes'] ?? json['count'];
    final Object? nameRaw = json['name'];
    return GlobalStop(
      id: json['id'] is String
          ? json['id'] as String
          : (json['id']?.toString() ?? ''),
      lat: _doubleOf(json['lat']),
      lng: _doubleOf(json['lng']),
      radiusM: radiusRaw is num ? radiusRaw.toDouble() : 30,
      passes: _intOf(passesRaw),
      name: nameRaw is String && nameRaw.isNotEmpty ? nameRaw : null,
      lines: List<StopLineRef>.unmodifiable(lines),
    );
  }
}

/// One predicted arrival item for a stop.
class StopArrivalItem {
  /// Creates a stop arrival item.
  const StopArrivalItem({
    required this.lineId,
    required this.code,
    required this.vehicleId,
    required this.etaS,
    required this.confidence,
    required this.sampleCount,
    required this.method,
  });

  /// Stable line id.
  final int lineId;

  /// Line code.
  final String code;

  /// Vehicle id.
  final int vehicleId;

  /// ETA in seconds.
  final int etaS;

  /// Confidence label.
  final String confidence;

  /// Sample count.
  final int sampleCount;

  /// Method label.
  final String method;

  /// Parses defensively.
  factory StopArrivalItem.fromJson(Map<String, dynamic> json) {
    final Object? lineRaw = json['line'] ?? json['l'] ?? json['lineId'];
    final Object? vehicleRaw =
        json['vehicle'] ?? json['v'] ?? json['vehicleId'];
    final Object? etaRaw = json['eta_s'] ?? json['etaS'] ?? json['eta'];
    final Object? confRaw = json['conf'] ?? json['confidence'];
    final Object? countRaw =
        json['n'] ?? json['sampleCount'] ?? json['samples'];
    final Object? methodRaw = json['m'] ?? json['method'];
    final Object? codeRaw = json['code'];
    return StopArrivalItem(
      lineId: _intOf(lineRaw),
      code: codeRaw is String ? codeRaw : (codeRaw?.toString() ?? ''),
      vehicleId: _intOf(vehicleRaw),
      etaS: _intOf(etaRaw),
      confidence: confRaw is String ? confRaw : (confRaw?.toString() ?? ''),
      sampleCount: _intOf(countRaw),
      method: methodRaw is String ? methodRaw : (methodRaw?.toString() ?? ''),
    );
  }
}

/// Predicted arrivals for a stop.
class StopArrivals {
  /// Creates stop arrivals.
  const StopArrivals({
    required this.stopId,
    required this.nowS,
    required this.items,
  });

  /// Opaque stop id.
  final String stopId;

  /// Server now, epoch seconds.
  final int nowS;

  /// Arrival items.
  final List<StopArrivalItem> items;

  /// Parses defensively.
  factory StopArrivals.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = _listOf(json['items']);
    final List<StopArrivalItem> items = <StopArrivalItem>[];
    for (final dynamic e in raw) {
      if (e is Map) {
        try {
          items.add(StopArrivalItem.fromJson(e.cast<String, dynamic>()));
        } on Object {
          // Skip malformed entries.
        }
      }
    }
    final Object? nowRaw = json['now'] ?? json['nowS'] ?? json['now_s'];
    final Object? idRaw = json['id'] ?? json['stopId'];
    return StopArrivals(
      stopId: idRaw is String ? idRaw : (idRaw?.toString() ?? ''),
      nowS: _intOf(nowRaw),
      items: List<StopArrivalItem>.unmodifiable(items),
    );
  }
}

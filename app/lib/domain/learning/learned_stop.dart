// De-identified learned stop point. Pure Dart, no Flutter imports.

/// A learned stop point produced by the data-learning subsystem.
class LearnedStop {
  /// Creates a learned stop.
  const LearnedStop({
    required this.id,
    required this.ordinal,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.passes,
  });

  /// Stop id.
  final String id;

  /// Ordinal along the route.
  final int ordinal;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Cluster radius in meters.
  final double radiusM;

  /// Number of passes contributing to this stop.
  final int passes;

  /// Parses a learned stop from JSON.
  factory LearnedStop.fromJson(Map<String, dynamic> json) {
    return LearnedStop(
      id: json['id'] as String,
      ordinal: (json['i'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      radiusM: (json['r'] as num?)?.toDouble() ?? 30,
      passes: (json['n'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of fetching learned stops for a line.
class LearnedStopsResult {
  /// Creates a learned stops result.
  const LearnedStopsResult({
    required this.direction,
    required this.stops,
    required this.fallback,
  });

  /// Travel direction (0 or 1).
  final int direction;

  /// Learned stops along the route.
  final List<LearnedStop> stops;

  /// Whether the payload falls back to static data.
  final bool fallback;

  /// Parses a learned stops result from JSON.
  factory LearnedStopsResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['stops'] as List<dynamic>?) ?? <dynamic>[];
    return LearnedStopsResult(
      direction: (json['dir'] as num?)?.toInt() ?? 0,
      stops: raw
          .map(
            (dynamic e) => LearnedStop.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      fallback: json['fallback'] as bool? ?? false,
    );
  }
}

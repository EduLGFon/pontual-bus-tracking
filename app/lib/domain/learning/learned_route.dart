// De-identified learned route polyline. Pure Dart, no Flutter imports.

/// A learned route polyline produced by the data-learning subsystem.
class LearnedRoute {
  /// Creates a learned route.
  const LearnedRoute({
    required this.version,
    required this.direction,
    required this.polyline,
    required this.trips,
    required this.computedAt,
    required this.fallback,
  });

  /// Learned route version.
  final int version;

  /// Travel direction (0 or 1).
  final int direction;

  /// Encoded polyline, or null when unavailable.
  final String? polyline;

  /// Number of trips contributing to this route.
  final int trips;

  /// ISO timestamp when the route was computed.
  final String? computedAt;

  /// Whether the payload falls back to static data.
  final bool fallback;

  /// Parses a learned route from JSON.
  factory LearnedRoute.fromJson(Map<String, dynamic> json) {
    return LearnedRoute(
      version: (json['v'] as num?)?.toInt() ?? 0,
      direction: (json['dir'] as num?)?.toInt() ?? 0,
      polyline: json['polyline'] as String?,
      trips: (json['trips'] as num?)?.toInt() ?? 0,
      computedAt: json['computed_at'] as String?,
      fallback: json['fallback'] as bool? ?? false,
    );
  }
}
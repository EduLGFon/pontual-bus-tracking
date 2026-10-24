// De-identified learned route polyline. Pure Dart, no Flutter imports.
class LearnedRoute {
  const LearnedRoute({
    required this.version,
    required this.direction,
    required this.polyline,
    required this.trips,
    required this.computedAt,
    required this.fallback,
  });

  final int version;
  final int direction;
  final String? polyline;
  final int trips;
  final String? computedAt;
  final bool fallback;

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
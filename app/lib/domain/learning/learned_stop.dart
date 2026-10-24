// De-identified learned stop point. Pure Dart, no Flutter imports.
class LearnedStop {
  const LearnedStop({
    required this.id,
    required this.ordinal,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.passes,
  });

  final String id;
  final int ordinal;
  final double lat;
  final double lng;
  final double radiusM;
  final int passes;

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

class LearnedStopsResult {
  const LearnedStopsResult({
    required this.direction,
    required this.stops,
    required this.fallback,
  });

  final int direction;
  final List<LearnedStop> stops;
  final bool fallback;

  factory LearnedStopsResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['stops'] as List<dynamic>?) ?? <dynamic>[];
    return LearnedStopsResult(
      direction: (json['dir'] as num?)?.toInt() ?? 0,
      stops: raw
          .map((dynamic e) =>
              LearnedStop.fromJson((e as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(growable: false),
      fallback: json['fallback'] as bool? ?? false,
    );
  }
}
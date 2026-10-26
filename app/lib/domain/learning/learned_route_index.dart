// In-memory index of published learned routes, used by place search.
// Pure Dart, no Flutter imports. Coordinates come only from published
// aggregates (polylines and stop centroids).
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/domain/learning/learned_stop.dart';

/// One published learned route entry (one direction of one line).
class LearnedRouteEntry {
  /// Creates an entry.
  const LearnedRouteEntry({
    required this.lineId,
    required this.code,
    required this.direction,
    required this.polyline,
    required this.points,
    required this.stops,
    required this.trips,
  });

  /// Line id.
  final int lineId;

  /// Line code.
  final String code;

  /// Travel direction (0 or 1).
  final int direction;

  /// Encoded polyline.
  final String polyline;

  /// Decoded polyline points.
  final List<LatLng> points;

  /// Learned stops along this direction.
  final List<LearnedStop> stops;

  /// Contributing trip count.
  final int trips;

  /// Parses an entry from the bulk endpoint JSON.
  factory LearnedRouteEntry.fromJson(Map<String, dynamic> json) {
    final String polyline = json['polyline'] as String? ?? '';
    final List<LatLng> points = polyline.isEmpty
        ? const <LatLng>[]
        : decodePolyline(polyline);
    final List<dynamic> rawStops =
        (json['stops'] as List<dynamic>?) ?? const <dynamic>[];
    return LearnedRouteEntry(
      lineId: (json['line'] as num).toInt(),
      code: json['code'] as String,
      direction: (json['dir'] as num?)?.toInt() ?? 0,
      polyline: polyline,
      points: points,
      stops: rawStops
          .map(
            (dynamic e) => LearnedStop.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      trips: (json['trips'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Index of all published learned routes, keyed for quick lookup.
class LearnedRoutesIndex {
  /// Creates an index from a list of entries.
  const LearnedRoutesIndex(this.entries);

  /// All published entries.
  final List<LearnedRouteEntry> entries;

  /// Parses the bulk endpoint response.
  factory LearnedRoutesIndex.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['routes'] as List<dynamic>?) ?? const <dynamic>[];
    return LearnedRoutesIndex(
      raw
          .map(
            (dynamic e) => LearnedRouteEntry.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }

  /// Empty index.
  static const LearnedRoutesIndex empty = LearnedRoutesIndex(
    <LearnedRouteEntry>[],
  );
}

// Pure geographic helpers for place search. No Flutter imports.
import 'dart:math' as math;

import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/domain/learning/learned_route_index.dart';

/// Minimum distance in meters from [point] to any segment of [polyline].
/// Returns [double.infinity] when the polyline has fewer than two points.
double minDistanceToPolylineM(LatLng point, List<LatLng> polyline) {
  if (polyline.length < 2) {
    if (polyline.length == 1) {
      return distM(point.lat, point.lng, polyline[0].lat, polyline[0].lng);
    }
    return double.infinity;
  }
  double best = double.infinity;
  for (int i = 0; i < polyline.length - 1; i++) {
    final double d = _pointToSegmentM(point, polyline[i], polyline[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

double _pointToSegmentM(LatLng p, LatLng a, LatLng b) {
  const double mPerDegLat = 111320.0;
  final double midLat = (a.lat + b.lat) / 2;
  final double mPerDegLng = 111320.0 * math.cos(midLat * math.pi / 180.0);
  final double ax = a.lng * mPerDegLng;
  final double ay = a.lat * mPerDegLat;
  final double bx = b.lng * mPerDegLng;
  final double by = b.lat * mPerDegLat;
  final double px = p.lng * mPerDegLng;
  final double py = p.lat * mPerDegLat;
  final double vx = bx - ax;
  final double vy = by - ay;
  final double wx = px - ax;
  final double wy = py - ay;
  final double len2 = vx * vx + vy * vy;
  double t = len2 == 0 ? 0 : (wx * vx + wy * vy) / len2;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final double cx = ax + t * vx;
  final double cy = ay + t * vy;
  final double dx = px - cx;
  final double dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

/// Minimum distance in meters from [point] to any of [stops].
double minDistanceToStopsM(LatLng point, List<LatLng> stops) {
  if (stops.isEmpty) return double.infinity;
  double best = double.infinity;
  for (final LatLng s in stops) {
    final double d = distM(point.lat, point.lng, s.lat, s.lng);
    if (d < best) best = d;
  }
  return best;
}

/// Whether a line entry passes near a place point.
bool linePassesNear({
  required LatLng place,
  required LearnedRouteEntry entry,
  double routeRadiusM = 500,
  double stopRadiusM = 300,
}) {
  final double routeD = minDistanceToPolylineM(place, entry.points);
  if (routeD <= routeRadiusM) return true;
  final List<LatLng> stopPoints = entry.stops
      .map((s) => LatLng(s.lat, s.lng))
      .toList();
  final double stopD = minDistanceToStopsM(place, stopPoints);
  return stopD <= stopRadiusM;
}

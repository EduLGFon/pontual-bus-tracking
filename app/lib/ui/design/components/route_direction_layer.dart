// RouteDirectionLayer: chevrons painted along an ordered route polyline so
// the travel direction reads at a glance. Pure placement helpers are
// exported for unit testing. No network, no new data source.
// See docs/ui/UI_SPEC.md 7.5.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/core/geo/geo.dart' as geo;

/// Cap on route direction arrows drawn on a line map.
const int maxRouteArrows = 40;

/// One arrow placement along a route.
@immutable
class RouteArrow {
  /// Creates a placement.
  const RouteArrow({
    required this.lat,
    required this.lng,
    required this.bearingDeg,
  });

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Bearing in degrees, 0..359, clockwise from north.
  final double bearingDeg;
}

/// Computes arrow placements along [points].
///
/// Points are assumed to be ordered along travel. Consecutive points
/// closer than 1 m are deduped. Returns an empty list for fewer than two
/// points or a route shorter than [minSpacingM]. Never exceeds
/// [maxArrows].
List<RouteArrow> routeArrowPlacements(
  List<LatLng> points, {
  double minSpacingM = 160,
  int maxArrows = maxRouteArrows,
}) {
  if (maxArrows <= 0) {
    return const <RouteArrow>[];
  }
  if (minSpacingM <= 0) {
    minSpacingM = 1;
  }
  // Dedupe consecutive points closer than 1 m.
  final List<LatLng> pts = <LatLng>[];
  for (final LatLng p in points) {
    if (pts.isEmpty ||
        geo.distM(
              pts.last.latitude,
              pts.last.longitude,
              p.latitude,
              p.longitude,
            ) >=
            1) {
      pts.add(p);
    }
  }
  if (pts.length < 2) {
    return const <RouteArrow>[];
  }

  // Cumulative distances.
  final List<double> cum = <double>[0];
  double total = 0;
  for (int i = 1; i < pts.length; i++) {
    total += geo.distM(
      pts[i - 1].latitude,
      pts[i - 1].longitude,
      pts[i].latitude,
      pts[i].longitude,
    );
    cum.add(total);
  }
  if (total < minSpacingM) {
    return const <RouteArrow>[];
  }

  final double spacing = math.max(minSpacingM, total / maxArrows);
  final List<RouteArrow> out = <RouteArrow>[];

  double d = spacing / 2;
  while (d < total - spacing / 4 && out.length < maxArrows) {
    // Find segment.
    int idx = 0;
    while (idx + 1 < cum.length && cum[idx + 1] <= d) {
      idx++;
    }
    if (idx + 1 >= pts.length) {
      break;
    }
    final double segLen = cum[idx + 1] - cum[idx];
    final double t = segLen <= 0 ? 0 : (d - cum[idx]) / segLen;
    final double lat =
        pts[idx].latitude + (pts[idx + 1].latitude - pts[idx].latitude) * t;
    final double lng =
        pts[idx].longitude + (pts[idx + 1].longitude - pts[idx].longitude) * t;
    final double dLat = pts[idx + 1].latitude - pts[idx].latitude;
    final double dLng = pts[idx + 1].longitude - pts[idx].longitude;
    final double latRad = lat * math.pi / 180;
    double bearing = math.atan2(dLng * math.cos(latRad), dLat) * 180 / math.pi;
    if (bearing < 0) {
      bearing += 360;
    }
    out.add(RouteArrow(lat: lat, lng: lng, bearingDeg: bearing));
    d += spacing;
  }
  return out;
}

/// Chevrons along a route polyline.
class RouteDirectionLayer extends StatelessWidget {
  /// Creates the layer.
  const RouteDirectionLayer({
    required this.points,
    required this.fill,
    required this.outline,
    this.maxArrows = maxRouteArrows,
    super.key,
  });

  /// Route points, ordered along travel.
  final List<LatLng> points;

  /// Arrow fill colour.
  final Color fill;

  /// Arrow outline colour.
  final Color outline;

  /// Cap on arrows drawn.
  final int maxArrows;

  @override
  Widget build(BuildContext context) {
    final List<RouteArrow> arrows = routeArrowPlacements(
      points,
      maxArrows: maxArrows,
    );
    if (arrows.isEmpty) {
      return const SizedBox.shrink();
    }
    return MarkerLayer(
      rotate: false,
      alignment: Alignment.center,
      markers: <Marker>[
        for (int i = 0; i < arrows.length; i++)
          Marker(
            point: LatLng(arrows[i].lat, arrows[i].lng),
            width: 18,
            height: 18,
            child: IgnorePointer(
              key: ValueKey<String>('route-arrow-$i'),
              child: ExcludeSemantics(
                child: Transform.rotate(
                  angle: arrows[i].bearingDeg * math.pi / 180,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: _RouteArrowPainter(fill: fill, outline: outline),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteArrowPainter extends CustomPainter {
  const _RouteArrowPainter({required this.fill, required this.outline});

  final Color fill;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final ui.Path p = ui.Path()
      ..moveTo(c.dx, c.dy - size.height * 0.45)
      ..lineTo(c.dx - size.width * 0.35, c.dy + size.height * 0.3)
      ..lineTo(c.dx + size.width * 0.35, c.dy + size.height * 0.3)
      ..close();
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
      p,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RouteArrowPainter old) =>
      old.fill != fill || old.outline != outline;
}

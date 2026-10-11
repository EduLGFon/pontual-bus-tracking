// Line map layer for the line screen: full-bleed flutter_map with the
// vehicle markers, the optional route polyline, the OSM attribution chip
// and the camera controls. The viewer's own location is never drawn:
// only viewers without location access see this map.
// See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/line/line_map_controls.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Maximum number of vehicle markers drawn at once. The sheet summarises
/// anything beyond this, so no vehicle is dropped silently.
const int maxMarkers = 20;

/// Route polyline casing width in dp, drawn under the coloured stroke.
const double routeCasingDp = 8;

/// Route polyline stroke width in dp.
const double routeStrokeDp = 5;

/// Dash segments of the dashed route line, in pixels.
const List<double> routeDashSegments = <double>[8, 8];

/// The map under the bottom sheet: tiles, scrim, markers and controls.
class LineMap extends StatefulWidget {
  /// Creates the line map.
  const LineMap({
    required this.lineKey,
    required this.vehicles,
    required this.tileUrlTemplate,
    required this.onPan,
    required this.onRecenter,
    this.httpClient,
    this.routePoints = const <LatLng>[],
    this.dashedRoute = false,
    this.selectedKey,
    this.onVehicleTap,
    this.panned = false,
    this.controlsBottomPadding = Space.x3,
    super.key,
  });

  /// Stable line key, used for the deterministic marker colour.
  final String lineKey;

  /// Vehicles to draw, already capped by the caller.
  final List<VehicleVM> vehicles;

  /// Tile URL template from the remote flags.
  final String tileUrlTemplate;

  /// Test-only HTTP client for tiles. Null uses the real network.
  final http.Client? httpClient;

  /// Route polyline points, empty until route data exists.
  final List<LatLng> routePoints;

  /// Draws the route dashed instead of solid.
  final bool dashedRoute;

  /// Internal id of the selected vehicle, never shown to users.
  final int? selectedKey;

  /// Called when a marker is tapped.
  final ValueChanged<VehicleVM>? onVehicleTap;

  /// True once the user has panned away from the automatic camera.
  final bool panned;

  /// Distance of the recenter control from the bottom of the map, so the
  /// sheet or the dock never hides it.
  final double controlsBottomPadding;

  /// Called when the user drags the map.
  final VoidCallback onPan;

  /// Called by the recenter control.
  final VoidCallback onRecenter;

  @override
  State<LineMap> createState() => LineMapState();
}

/// State of the line map. Exposes the camera commands the screen needs.
class LineMapState extends State<LineMap> {
  final MapController _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Fits the camera to the live vehicles, else to the service-area bounds.
  /// Called on enter, on recenter and on sheet settle, never per frame:
  /// [padding] reserves the space covered by the sheet or the side panel.
  void fitToContent({EdgeInsets padding = EdgeInsets.zero}) {
    final List<LatLng> points = widget.vehicles
        .map((VehicleVM v) => LatLng(v.lat, v.lng))
        .toList();
    if (points.length >= 2) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: padding,
          maxZoom: 16,
        ),
      );
      return;
    }
    if (points.length == 1) {
      _map.move(points.first, 15);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(bounds: mapBounds, padding: padding, maxZoom: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? pulse = LivePulseScope.maybeOf(context);
    final colors = context.colors;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          // One RepaintBoundary for the whole map, never one per marker.
          child: RepaintBoundary(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _initialCenter(),
                initialZoom: 13,
                minZoom: mapMinZoom,
                maxZoom: mapMaxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: mapBounds),
                backgroundColor: colors.surface,
                onPositionChanged: (MapCamera camera, bool hasGesture) {
                  if (hasGesture) {
                    widget.onPan();
                  }
                },
              ),
              children: <Widget>[
                osmTileLayer(
                  widget.tileUrlTemplate,
                  httpClient: widget.httpClient,
                ),
                // Premium muting without a GPU cost: one tinted box above
                // the tiles. No ColorFiltered, no blend mode, no blur.
                ColoredBox(color: colors.mapScrim),
                if (widget.routePoints.isNotEmpty) ...<Widget>[
                  _routeLayer(
                    color: colors.bg,
                    width: routeCasingDp,
                    dashed: false,
                  ),
                  _routeLayer(
                    color: _lineColor(context),
                    width: routeStrokeDp,
                    dashed: widget.dashedRoute,
                  ),
                ],
                MarkerLayer(
                  rotate: false,
                  alignment: Alignment.center,
                  markers: <Marker>[
                    for (final VehicleVM v in widget.vehicles.take(maxMarkers))
                      Marker(
                        point: LatLng(v.lat, v.lng),
                        width: markerHitDp,
                        height: markerHitDp,
                        child: VehicleMarker(
                          vehicle: v,
                          lineKey: widget.lineKey,
                          selected: v.key == widget.selectedKey,
                          pulse: pulse,
                          ringColor: colors.surface,
                          onTap: widget.onVehicleTap == null
                              ? null
                              : () => widget.onVehicleTap!(v),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const MapBackButton(),
        const MapAttributionChip(),
        if (widget.panned)
          MapRecenterButton(
            bottomPadding: widget.controlsBottomPadding,
            onTap: () {
              widget.onRecenter();
              fitToContent();
            },
          ),
      ],
    );
  }

  /// Centre used before the first camera fit: the live vehicles first, else
  /// the service-area centre at zoom 13.
  LatLng _initialCenter() {
    if (widget.vehicles.isNotEmpty) {
      final VehicleVM first = widget.vehicles.first;
      return LatLng(first.lat, first.lng);
    }
    return mapBounds.center;
  }

  /// Colour of the route line, taken from the deterministic line palette.
  Color _lineColor(BuildContext context) {
    return lineColorOf(
      widget.lineKey,
      brightness: Theme.of(context).brightness,
    );
  }

  /// One route polyline: the casing under the coloured stroke.
  Widget _routeLayer({
    required Color color,
    required double width,
    bool dashed = false,
  }) {
    return PolylineLayer<Object>(
      polylines: <Polyline<Object>>[
        Polyline<Object>(
          points: widget.routePoints,
          strokeWidth: width,
          color: color,
          pattern: dashed
              ? StrokePattern.dashed(segments: routeDashSegments)
              : const StrokePattern.solid(),
        ),
      ],
    );
  }
}

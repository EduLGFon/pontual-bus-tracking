// Line map layer for the line screen: full-bleed flutter_map with the
// vehicle markers, the viewer dot, the optional route polyline, the OSM
// attribution chip and the camera controls. The viewer dot comes from an
// on-device one-shot lookup and is drawn only, never sent anywhere.
// See docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:pontual/core/geo/geo.dart' as geo;
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/line_colors.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/line/line_map_controls.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Maximum number of vehicle markers drawn at once. The sheet summarises
/// anything beyond this, so no vehicle is dropped silently.
const int maxMarkers = 20;

/// Zoom of the city-centre fallback: wide enough to show the served area.
const double cityZoom = 13;

/// Zoom of the viewer recenter: close enough to read streets, wide enough
/// to see the whole neighbourhood around the viewer dot.
const double neighbourhoodZoom = 14;

/// Zoom used when focusing one bus: street detail around the marker.
const double vehicleFocusZoom = 15;

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
    required this.onLocateViewer,
    required this.onLocateBus,
    this.httpClient,
    this.routePoints = const <LatLng>[],
    this.stops = const <StopPoint>[],
    this.dashedRoute = false,
    this.selectedKey,
    this.onVehicleTap,
    this.onStopTap,
    this.viewerPosition,
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

  /// City bus stops to draw as small dots, empty until mapped. Drawn
  /// under the vehicles; survey-scale hundreds need a zoom gate or cap,
  /// but the mapped handful needs none.
  final List<StopPoint> stops;

  /// Draws the route dashed instead of solid.
  final bool dashedRoute;

  /// Internal id of the selected vehicle, never shown to users.
  final int? selectedKey;

  /// Viewer position from the on-device one-shot lookup, null when
  /// unknown. Drawn only, never sent anywhere.
  final LatLng? viewerPosition;

  /// Called when a marker is tapped.
  final ValueChanged<VehicleVM>? onVehicleTap;

  /// Called when a stop dot is tapped. Null keeps stops decorative.
  final ValueChanged<StopPoint>? onStopTap;

  /// True once the user has panned away from the automatic camera.
  final bool panned;

  /// Distance of the recenter control from the bottom of the map, so the
  /// sheet or the dock never hides it.
  final double controlsBottomPadding;

  /// Called when the user drags the map.
  final VoidCallback onPan;

  /// Called by the viewer locate button. The screen centres the camera on
  /// the viewer (city centre fallback) through [LineMapState.centerOnViewer].
  final VoidCallback onLocateViewer;

  /// Called by the nearest-bus button. The screen centres the closest bus
  /// through [LineMapState.centerOnClosestBus].
  final VoidCallback onLocateBus;

  @override
  State<LineMap> createState() => LineMapState();
}

/// State of the line map. Exposes the camera commands the screen needs.
class LineMapState extends State<LineMap> {
  final MapController _map = MapController();

  /// Reloads the visible tiles when the throttled-burst retry fires.
  final StreamController<void> _tileReset = StreamController<void>();
  Timer? _tileRetryTimer;
  int _tileReloadAttempts = 0;
  DateTime? _lastTileErrorAt;
  bool _viewerFitted = false;

  @override
  void dispose() {
    _tileRetryTimer?.cancel();
    _tileReset.close();
    _map.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LineMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The viewer lookup resolves after the first frame. Frame it once when
    // it lands, unless the rider already took the camera or live vehicles
    // own the view. Deferred past the frame: moving the camera rebuilds
    // the map, which is illegal mid-build.
    final LatLng? viewer = widget.viewerPosition;
    if (!_viewerFitted &&
        viewer != null &&
        oldWidget.viewerPosition == null &&
        !widget.panned &&
        widget.vehicles.isEmpty) {
      _viewerFitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.panned) {
          _map.move(viewer, neighbourhoodZoom);
        }
      });
    }
  }

  /// Counts a failed tile and schedules one bounded reload of the visible
  /// tiles. The public raster host throttles the burst fired when the map
  /// opens or a fast zoom settles; without this the failed tiles stay blank
  /// until the next user gesture. No tile coordinates are read or logged.
  void _onTileError() {
    if (!mounted || _tileReset.isClosed) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTileErrorAt;
    if (last == null || now.difference(last) > tileErrorBurstWindow) {
      _tileReloadAttempts = 0;
    }
    _lastTileErrorAt = now;
    if (_tileReloadAttempts >= maxTileReloadAttempts) {
      return;
    }
    if (_tileRetryTimer?.isActive == true) {
      return;
    }
    _tileRetryTimer = Timer(tileReloadDelay(_tileReloadAttempts), () {
      _tileReloadAttempts += 1;
      if (mounted && !_tileReset.isClosed) {
        _tileReset.add(null);
      }
    });
  }

  /// Centres the camera on the viewer at neighbourhood zoom. Falls back to
  /// the city centre at city zoom when the viewer position is unknown.
  /// Called by the recenter control only, never automatically.
  void centerOnViewer() {
    final LatLng? viewer = widget.viewerPosition;
    if (viewer != null) {
      _map.move(viewer, neighbourhoodZoom);
      return;
    }
    _map.move(mapBounds.center, cityZoom);
  }

  /// Centres the bus closest to the viewer at street zoom. Without a
  /// viewer position the camera centre is the reference instead. With no
  /// live vehicles it falls back to the city centre, like every other
  /// focus without a better position. Called by the bus button only.
  void centerOnClosestBus() {
    if (widget.vehicles.isEmpty) {
      _map.move(mapBounds.center, cityZoom);
      return;
    }
    final LatLng reference = widget.viewerPosition ?? _map.camera.center;
    VehicleVM closest = widget.vehicles.first;
    double closestM = geo.distM(
      reference.latitude,
      reference.longitude,
      closest.lat,
      closest.lng,
    );
    for (final VehicleVM vehicle in widget.vehicles.skip(1)) {
      final double distanceM = geo.distM(
        reference.latitude,
        reference.longitude,
        vehicle.lat,
        vehicle.lng,
      );
      if (distanceM < closestM) {
        closestM = distanceM;
        closest = vehicle;
      }
    }
    _map.move(LatLng(closest.lat, closest.lng), vehicleFocusZoom);
  }

  /// Fits the camera to the live vehicles, else to the service-area bounds
  /// (city centre). Called on enter and when the map is first revealed,
  /// never when the sheet moves: expanding the line details must not move
  /// the camera. [padding] reserves the space covered by the sheet or the
  /// side panel.
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
      _map.move(points.first, vehicleFocusZoom);
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
                initialZoom: cityZoom,
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
                  reset: _tileReset.stream,
                  onTileError: _onTileError,
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
                if (widget.stops.isNotEmpty)
                  MarkerLayer(
                    rotate: false,
                    alignment: Alignment.center,
                    markers: <Marker>[
                      for (final StopPoint stop in widget.stops)
                        Marker(
                          key: ValueKey<String>('stop-${stop.id}'),
                          point: LatLng(stop.lat, stop.lng),
                          width: 44,
                          height: 44,
                          child: _StopDot(
                            name: stop.name,
                            onTap: widget.onStopTap == null
                                ? null
                                : () => widget.onStopTap!(stop),
                          ),
                        ),
                    ],
                  ),
                MarkerLayer(
                  rotate: false,
                  alignment: Alignment.center,
                  markers: <Marker>[
                    for (final VehicleVM v in widget.vehicles.take(maxMarkers))
                      Marker(
                        // Stable keys: the age sort reorders every tick, so
                        // reconciliation by index would attach marker state
                        // (and repaints) to the wrong bus.
                        key: ValueKey<int>(v.key),
                        point: LatLng(v.lat, v.lng),
                        width: markerHitDp,
                        height: markerHitDp,
                        child: VehicleMarker(
                          key: ValueKey<String>('marker-${v.key}'),
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
                    if (widget.viewerPosition != null)
                      Marker(
                        point: widget.viewerPosition!,
                        width: markerHitDp,
                        height: markerHitDp,
                        child: _ViewerDot(),
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
          MapLocateControls(
            bottomPadding: widget.controlsBottomPadding,
            onLocateViewer: widget.onLocateViewer,
            onLocateBus: widget.onLocateBus,
          ),
      ],
    );
  }

  /// Centre used before the first camera fit: the viewer first, then the
  /// live vehicles, else the city centre (service-area centre). The city
  /// centre is the fallback for every case with no better position: no
  /// location found, permission missing, lookup still loading, map just
  /// opened.
  LatLng _initialCenter() {
    final LatLng? viewer = widget.viewerPosition;
    if (viewer != null) {
      return viewer;
    }
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

/// Viewer dot: ink core, surface ring, primary halo. Token colours only,
// no new palette: the shape (small dot, never a bus glyph) tells it apart
// from vehicle markers, and the halo is decorative, never the only cue.
class _ViewerDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Sua posição',
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bus stop dot: small muted circle with a surface ring. Never a bus
/// glyph and never pulsing, so it cannot read as a vehicle. Names come
/// from survey or OSM data, never invented. The 44 dp hit target opens
/// the stop sheet; the visible dot stays 10 dp.
class _StopDot extends StatelessWidget {
  /// Creates a stop dot with the posted [name], if mapped.
  const _StopDot({this.name, this.onTap});

  /// Posted stop name, null when unmapped.
  final String? name;

  /// Opens the stop sheet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String label = name == null || name!.isEmpty
        ? 'Ponto de ônibus'
        : 'Ponto: $name';
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.pill,
      minSize: 44,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colors.inkMuted,
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: 2),
          ),
        ),
      ),
    );
  }
}

// Widget tests for the line map camera and tile reload reliability.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

Widget _app({
  List<VehicleVM> vehicles = const <VehicleVM>[],
  List<LatLng> routePoints = const <LatLng>[],
}) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(
      body: LineMap(
        lineKey: 'seven',
        vehicles: vehicles,
        tileUrlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
        httpClient: MockClient((_) async => http.Response.bytes(<int>[], 404)),
        routePoints: routePoints,
        onPan: () {},
        onLocateViewer: () {},
        onLocateBus: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('no vehicles and no route opens at city zoom on map center', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.fitToContent();
    await tester.pump();
    expect(state.mapController.camera.center, mapBounds.center);
    expect(state.mapController.camera.zoom, cityZoom);
  });

  testWidgets('no vehicles with route fits the route, not the whole map', (
    tester,
  ) async {
    const List<LatLng> route = <LatLng>[
      LatLng(-18.70, -39.85),
      LatLng(-18.75, -39.90),
    ];
    await tester.pumpWidget(_app(routePoints: route));
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.fitToContent();
    await tester.pump();
    // Not the whole service area.
    expect(state.mapController.camera.center, isNot(mapBounds.center));
    expect(state.mapController.camera.zoom, greaterThan(cityZoom));
    expect(state.mapController.camera.zoom, lessThanOrEqualTo(15));
    final LatLng routeCenter = LatLngBounds.fromPoints(route).center;
    expect(
      state.mapController.camera.center.latitude,
      closeTo(routeCenter.latitude, 1e-3),
    );
    expect(
      state.mapController.camera.center.longitude,
      closeTo(routeCenter.longitude, 1e-3),
    );
  });

  testWidgets('theme toggle requests exactly one tile reload', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    int count = 0;
    state.tileResets.listen((_) => count++);
    // Find the theme toggle by its tooltip.
    await tester.tap(find.byTooltip('Mapa escuro'));
    await tester.pump();
    await tester.pump();
    expect(count, 1);
  });

  testWidgets('route points arriving later refit the camera', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    const List<LatLng> route = <LatLng>[
      LatLng(-18.70, -39.85),
      LatLng(-18.75, -39.90),
    ];
    await tester.pumpWidget(_app(routePoints: route));
    await tester.pump();
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    expect(state.mapController.camera.center, isNot(mapBounds.center));
    expect(state.mapController.camera.zoom, greaterThan(cityZoom));
    expect(state.mapController.camera.zoom, lessThanOrEqualTo(15));
    final LatLng routeCenter = LatLngBounds.fromPoints(route).center;
    expect(
      state.mapController.camera.center.latitude,
      closeTo(routeCenter.latitude, 1e-3),
    );
    expect(
      state.mapController.camera.center.longitude,
      closeTo(routeCenter.longitude, 1e-3),
    );
  });

  testWidgets('panned map does not refit when route points arrive', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    // A panned map must not refit when route points arrive.
    const List<LatLng> route = <LatLng>[
      LatLng(-18.70, -39.85),
      LatLng(-18.75, -39.90),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualLightTheme(),
        home: Scaffold(
          body: LineMap(
            lineKey: 'seven',
            vehicles: const <VehicleVM>[],
            tileUrlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
            httpClient: MockClient(
              (_) async => http.Response.bytes(<int>[], 404),
            ),
            routePoints: const <LatLng>[],
            panned: true,
            onPan: () {},
            onLocateViewer: () {},
            onLocateBus: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final LineMapState before = tester.state(find.byType(LineMap));
    final double zoomBefore = before.mapController.camera.zoom;
    final LatLng centerBefore = before.mapController.camera.center;
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualLightTheme(),
        home: Scaffold(
          body: LineMap(
            lineKey: 'seven',
            vehicles: const <VehicleVM>[],
            tileUrlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
            httpClient: MockClient(
              (_) async => http.Response.bytes(<int>[], 404),
            ),
            routePoints: route,
            panned: true,
            onPan: () {},
            onLocateViewer: () {},
            onLocateBus: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final LineMapState after = tester.state(find.byType(LineMap));
    expect(after.mapController.camera.center, centerBefore);
    expect(after.mapController.camera.zoom, zoomBefore);
  });
}

// Tests for route direction arrows and vehicle marker geometry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/core/geo/geo.dart' as geo;
import 'package:pontual/ui/design/components/route_direction_layer.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

void main() {
  test('eastbound route bearings are ~90', () {
    final List<LatLng> pts = <LatLng>[
      for (int i = 0; i < 6; i++) LatLng(-18.72, -39.85 + i * 0.001),
    ];
    final List<RouteArrow> arrows = routeArrowPlacements(pts);
    expect(arrows, isNotEmpty);
    expect(arrows.length, lessThanOrEqualTo(40));
    for (final RouteArrow a in arrows) {
      expect(a.bearingDeg, closeTo(90, 2));
    }
  });

  test('no arrow at endpoints', () {
    final List<LatLng> pts = <LatLng>[
      for (int i = 0; i < 6; i++) LatLng(-18.72, -39.85 + i * 0.001),
    ];
    final List<RouteArrow> arrows = routeArrowPlacements(pts);
    // first arrow not at first point
    expect(arrows.first.lng, isNot(closeTo(pts.first.longitude, 1e-9)));
    // spacing covers the route: last arrow before end
    final double total = geo.distM(
      pts.first.latitude,
      pts.first.longitude,
      pts.last.latitude,
      pts.last.longitude,
    );
    // approximate: at least one arrow and not at endpoint
    expect(arrows.last.lng, lessThan(pts.last.longitude));
    expect(total, greaterThan(80));
  });

  test('northbound bearing ~0', () {
    final List<LatLng> pts = <LatLng>[
      for (int i = 0; i < 6; i++) LatLng(i * 0.001, 0),
    ];
    final List<RouteArrow> arrows = routeArrowPlacements(pts);
    for (final RouteArrow a in arrows) {
      expect(a.bearingDeg, closeTo(0, 2));
    }
  });

  test('southbound bearing ~180', () {
    final List<LatLng> pts = <LatLng>[
      for (int i = 5; i >= 0; i--) LatLng(i * 0.001, 0),
    ];
    final List<RouteArrow> arrows = routeArrowPlacements(pts);
    for (final RouteArrow a in arrows) {
      expect(a.bearingDeg, closeTo(180, 2));
    }
  });

  test('short route returns empty', () {
    const List<LatLng> pts = <LatLng>[LatLng(0, 0), LatLng(0, 0.00001)];
    expect(routeArrowPlacements(pts), isEmpty);
  });

  test('max arrow cap respected on long route', () {
    final List<LatLng> pts = <LatLng>[
      for (int i = 0; i < 200; i++) LatLng(0, i * 0.01),
    ];
    final List<RouteArrow> arrows = routeArrowPlacements(pts);
    expect(arrows.length, lessThanOrEqualTo(40));
    expect(arrows.length, 40);
  });

  test('marker geometry fits in hit box', () {
    const double normalRadius = markerBodyDp * 0.5;
    const double selectedRadius = markerBodyDp * 0.56;
    expect(
      normalRadius + headingArrowTipOffsetDp + headingArrowStrokeDp / 2,
      lessThanOrEqualTo(markerHitDp / 2),
    );
    expect(
      selectedRadius + headingArrowTipOffsetDp + headingArrowStrokeDp / 2,
      lessThanOrEqualTo(markerHitDp / 2),
    );
  });

  testWidgets('LineMap renders route arrows and keeps them pointer-inert', (
    tester,
  ) async {
    final List<LatLng> pts = <LatLng>[
      for (int i = 0; i < 6; i++) LatLng(-18.72, -39.85 + i * 0.001),
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
            routePoints: pts,
            onPan: () {},
            onLocateViewer: () {},
            onLocateBus: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.fitToContent();
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('route-arrow-0')), findsOneWidget);
    final IgnorePointer arrow = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey<String>('route-arrow-0')),
    );
    expect(arrow.ignoring, isTrue);
    final int arrows = tester.widgetList(find.byType(IgnorePointer)).length;
    expect(arrows, lessThanOrEqualTo(maxRouteArrows));
    expect(find.byType(IgnorePointer), findsAtLeastNWidgets(1));
    final center = state.mapController.camera.center;
    expect(center.latitude, closeTo(-18.72, 0.01));
    expect(center.longitude, closeTo(-39.8475, 0.01));
  });
}

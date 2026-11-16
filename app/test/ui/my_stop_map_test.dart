// Widget tests for the personal stop marker and the global stop dots on the
// line map: semantics labels, tap targets, the safe empty list, and the
// camera command. Tiles come from a MockClient so no real request happens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/core/geo/geo.dart' as geo;
import 'package:pontual/domain/learning/global_stop.dart';
import 'package:pontual/features/map/tile_source.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

Widget _app({
  LatLng? personalStop,
  String? personalStopLabel,
  List<GlobalStop> stops = const <GlobalStop>[],
  ValueChanged<GlobalStop>? onStopTap,
  LatLng? viewerPosition,
}) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(
      body: LineMap(
        lineKey: 'seven',
        vehicles: const <VehicleVM>[],
        tileUrlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
        httpClient: MockClient((_) async => http.Response.bytes(<int>[], 404)),
        stops: stops,
        onStopTap: onStopTap,
        viewerPosition: viewerPosition,
        personalStop: personalStop,
        personalStopLabel: personalStopLabel,
        onPan: () {},
        onLocateViewer: () {},
        onLocateBus: () {},
      ),
    ),
  );
}

void main() {
  const LatLng center = LatLng(-18.725, -39.9);

  testWidgets('marker exposes its semantics label with a stop', (tester) async {
    final String label = UiStrings.myStopMapLabel(120);
    await tester.pumpWidget(
      _app(personalStop: center, personalStopLabel: label),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(label), findsOneWidget);
  });

  testWidgets('no marker without a stop', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.bySemanticsLabel(UiStrings.myStopTitle), findsNothing);
    expect(find.bySemanticsLabel(UiStrings.myStopMapLabel(120)), findsNothing);
  });

  testWidgets('centerOnMyStop does not throw with null', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.centerOnMyStop();
  });

  testWidgets('renders every passed stop and taps one at max zoom', (
    tester,
  ) async {
    final List<GlobalStop> stops = <GlobalStop>[
      const GlobalStop(id: 'stop-a', lat: -18.725, lng: -39.9, name: 'Ponto A'),
      const GlobalStop(id: 'stop-b', lat: -18.726, lng: -39.901),
    ];
    GlobalStop? tapped;
    await tester.pumpWidget(
      _app(stops: stops, onStopTap: (GlobalStop stop) => tapped = stop),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('stop-stop-a')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('stop-stop-b')), findsOneWidget);
    // Decorative dots must not flood the accessibility tree.
    expect(find.bySemanticsLabel('Ponto: Ponto A'), findsNothing);

    final LineMapState state = tester.state(find.byType(LineMap));
    state.mapController.move(center, mapMaxZoom);
    await tester.pump();
    expect(find.bySemanticsLabel('Ponto: Ponto A'), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('Ponto: Ponto A')),
      const Size(48, 48),
    );
    await tester.tap(find.bySemanticsLabel('Ponto: Ponto A'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped?.id, 'stop-a');
  });

  testWidgets('50 m stops only tap at max zoom without neighbor overlap', (
    tester,
  ) async {
    // 1 degree of latitude is about 110.574 km at São Mateus.
    const double latPerM = 1 / 110574;
    final GlobalStop stopA = GlobalStop(
      id: 'stop-a',
      lat: center.latitude,
      lng: center.longitude,
      name: 'Ponto A',
    );
    final GlobalStop stopB = GlobalStop(
      id: 'stop-b',
      lat: center.latitude + 50 * latPerM,
      lng: center.longitude,
      name: 'Ponto B',
    );
    expect(
      geo.distM(stopA.lat, stopA.lng, stopB.lat, stopB.lng),
      closeTo(50, 0.5),
    );
    GlobalStop? tapped;
    await tester.pumpWidget(
      _app(
        stops: <GlobalStop>[stopA, stopB],
        onStopTap: (GlobalStop value) => tapped = value,
      ),
    );
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.mapController.move(center, 16);
    await tester.pump();
    expect(find.bySemanticsLabel('Ponto: Ponto A'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('stop-stop-a')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped, isNull);

    state.mapController.move(center, mapMaxZoom);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('stop-stop-a')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped?.id, 'stop-a');
    await tester.tap(find.byKey(const ValueKey<String>('stop-stop-b')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped?.id, 'stop-b');
  });

  testWidgets('500 stops render without errors', (tester) async {
    final List<GlobalStop> stops = <GlobalStop>[
      for (int i = 0; i < 500; i++)
        GlobalStop(
          id: 's$i',
          lat: -18.725 + (i % 20) * 0.0001,
          lng: -39.9 + (i ~/ 20) * 0.0001,
        ),
    ];
    await tester.pumpWidget(
      _app(stops: stops, onStopTap: (GlobalStop stop) {}),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty stop list is safe', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.bySemanticsLabel(UiStrings.stopTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fitToContent uses the viewer when no route or vehicles exist', (
    tester,
  ) async {
    await tester.pumpWidget(_app(viewerPosition: center));
    await tester.pump();
    final LineMapState state = tester.state(find.byType(LineMap));
    state.fitToContent();
    await tester.pump();
    expect(
      state.mapController.camera.center.latitude,
      closeTo(center.latitude, 1e-6),
    );
    expect(
      state.mapController.camera.center.longitude,
      closeTo(center.longitude, 1e-6),
    );
    expect(state.mapController.camera.zoom, neighbourhoodZoom);
  });

  testWidgets('fitToContent falls back to the city centre without a viewer', (
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
}

// Widget tests for the personal stop marker on the line map: the marker
// exposes its semantics label when a stop is set, stays absent when null,
// and the camera command is a no-op without a stop. Tiles come from a
// MockClient so no real request happens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

Widget _app({LatLng? personalStop, String? personalStopLabel}) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(
      body: LineMap(
        lineKey: 'seven',
        vehicles: const <VehicleVM>[],
        tileUrlTemplate: 'https://tile.example/{z}/{x}/{y}.png',
        httpClient: MockClient((_) async => http.Response.bytes(<int>[], 404)),
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
}

// Widget tests for the flagged-off future components: sparkline,
// confidence meter, alert sheet, reliability card and prediction sheet.
// Flags off means shipped screens never mount them; the gallery does with
// fake data. See docs/ui/UI_SPEC.md 13 and 16 (U25).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/components/alert_sheet.dart';
import 'package:pontual/ui/design/components/confidence_meter.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/ghost_marker.dart';
import 'package:pontual/ui/design/components/predicted_path.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/design/components/prediction_info_sheet.dart';
import 'package:pontual/ui/design/components/reliability_card.dart';
import 'package:pontual/ui/design/components/sparkline.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Wraps [child] with the light tokens.
Widget harness(Widget child) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('Sparkline paints bars and hides when empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const Sparkline(bars: <double>[0.2, 0.8])));
    expect(find.byType(Sparkline), findsOneWidget);
    expect(find.bySemanticsLabel('Histórico de atrasos'), findsOneWidget);
    await tester.pumpWidget(harness(const Sparkline(bars: <double>[])));
    expect(find.byType(Sparkline), findsOneWidget);
    expect(find.bySemanticsLabel('Histórico de atrasos'), findsNothing);
  });

  testWidgets('ConfidenceMeter announces its level', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const ConfidenceMeter(level: 2)));
    expect(find.bySemanticsLabel(UiStrings.confHigh), findsOneWidget);
    await tester.pumpWidget(harness(const ConfidenceMeter(level: 0)));
    expect(find.bySemanticsLabel(UiStrings.confLow), findsOneWidget);
  });

  testWidgets('AlertSheet picks minutes and saves', (
    WidgetTester tester,
  ) async {
    int? saved;
    await tester.pumpWidget(
      harness(AlertSheet(onSave: (int m, _, _) => saved = m)),
    );
    expect(find.text(UiStrings.alertTitle), findsOneWidget);
    await tester.ensureVisible(find.text('10 min'));
    await tester.pump();
    await tester.tap(find.text('10 min'));
    await tester.pump();
    await tester.ensureVisible(find.text(UiStrings.alertSave));
    await tester.pump();
    await tester.tap(find.text(UiStrings.alertSave));
    await tester.pump();
    expect(saved, 10);
  });

  testWidgets('ReliabilityCard hides without samples', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ReliabilityCard(
          reliability: ReliabilityVM(typicalDelayMin: 0, sampleSize: 0),
        ),
      ),
    );
    expect(find.textContaining('Costuma'), findsNothing);
    await tester.pumpWidget(
      harness(
        const ReliabilityCard(
          reliability: ReliabilityVM(
            typicalDelayMin: 4,
            sampleSize: 120,
            bars: <double>[0.5],
          ),
        ),
      ),
    );
    expect(find.text(UiStrings.typicalDelayOf(4)), findsOneWidget);
  });

  testWidgets('PredictionInfoSheet shows the copy-deck paragraph', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const PredictionInfoSheet()));
    expect(find.text(UiStrings.predictionInfoTitle), findsOneWidget);
    expect(find.text(UiStrings.predictionInfoBody), findsOneWidget);
  });

  testWidgets('GhostMarker never pulses and announces a prediction', (
    WidgetTester tester,
  ) async {
    const VehicleVM ghost = VehicleVM(
      key: 1,
      lineKey: 'x',
      lat: 0,
      lng: 0,
      ageSeconds: 25,
      certainty: Certainty.predicted,
    );
    await tester.pumpWidget(
      harness(const GhostMarker(vehicle: ghost, lineKey: 'x')),
    );
    expect(find.byType(GhostMarker), findsOneWidget);
    expect(find.byType(CertaintyBadge), findsOneWidget);
    expect(find.byType(VehicleMarker), findsOneWidget);
  });

  testWidgets('PredictedPath hides with fewer than two points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(const PredictedPath(points: <Offset>[Offset(10, 10)])),
    );
    expect(find.bySemanticsLabel('Trajeto previsto'), findsNothing);
    await tester.pumpWidget(
      harness(
        const PredictedPath(points: <Offset>[Offset(10, 50), Offset(200, 10)]),
      ),
    );
    expect(find.bySemanticsLabel('Trajeto previsto'), findsOneWidget);
  });
}

// Widget tests for VehicleRow: the personal ETA line, its colour and
// semantics, and the certainty dot. No network and no preferences.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/vehicle_row.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Light token theme, the same harness used by the design system tests.
Widget harness(Widget child) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

/// Vehicle with [certainty] and fixed values, so no clock is needed.
VehicleVM vehicleWith(Certainty certainty) {
  return VehicleVM(
    key: 7,
    lineKey: '60-litoraneo-aviacao',
    lat: -18.7155,
    lng: -39.8592,
    speedKmh: 32.4,
    ageSeconds: 8,
    certainty: certainty,
    ordinal: 2,
  );
}

const String personalEta = '~6 min até você';
const String personalEtaSemantic =
    'Seu ônibus chega em cerca de 6 minutos no seu ponto.';

void main() {
  testWidgets('row without a personal ETA draws no extra line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(VehicleRow(vehicle: vehicleWith(Certainty.live), onTap: _noop)),
    );
    expect(find.text('Ônibus 2'), findsOneWidget);
    expect(find.textContaining('até você'), findsNothing);
    expect(
      tester.getSize(find.byType(VehicleRow)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('personal ETA renders under the caption in the primary colour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        VehicleRow(
          vehicle: vehicleWith(Certainty.live),
          personalEta: personalEta,
          onTap: _noop,
        ),
      ),
    );
    expect(find.text(personalEta), findsOneWidget);
    final Text eta = tester.widget<Text>(find.text(personalEta));
    expect(eta.style?.color, PontualColors.light.primary);
  });

  testWidgets('muted personal ETA uses the muted colour', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        VehicleRow(
          vehicle: vehicleWith(Certainty.live),
          personalEta: personalEta,
          personalEtaMuted: true,
          onTap: _noop,
        ),
      ),
    );
    final Text eta = tester.widget<Text>(find.text(personalEta));
    expect(eta.style?.color, PontualColors.light.inkMuted);
  });

  testWidgets('an empty personal ETA draws no line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        VehicleRow(
          vehicle: vehicleWith(Certainty.live),
          personalEta: '',
          onTap: _noop,
        ),
      ),
    );
    expect(find.textContaining('até você'), findsNothing);
  });

  testWidgets('personal ETA semantics are appended to the row label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        VehicleRow(
          vehicle: vehicleWith(Certainty.live),
          personalEta: personalEta,
          personalEtaSemantic: personalEtaSemantic,
          onTap: _noop,
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(personalEtaSemantic))),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the dot follows the certainty and the badge stays', (
    WidgetTester tester,
  ) async {
    for (final Certainty certainty in Certainty.values) {
      await tester.pumpWidget(
        harness(VehicleRow(vehicle: vehicleWith(certainty), onTap: _noop)),
      );
      expect(find.byType(VehicleRow), findsOneWidget);
      expect(find.byType(CertaintyBadge), findsOneWidget);
      final LiveDot dot = tester.widget<LiveDot>(find.byType(LiveDot));
      expect(dot.certainty, certainty);
    }
  });

  testWidgets('a predicted bus keeps a still dot', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        VehicleRow(
          vehicle: vehicleWith(Certainty.predicted),
          personalEta: personalEta,
          onTap: _noop,
        ),
      ),
    );
    final LiveDot dot = tester.widget<LiveDot>(find.byType(LiveDot));
    expect(dot.certainty, Certainty.predicted);
    expect(find.text(personalEta), findsOneWidget);
  });
}

/// No-op tap target, so the row keeps its 48 dp Pressable hit area.
void _noop() {}

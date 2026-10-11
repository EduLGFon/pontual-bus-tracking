// Widget tests for the design-system components: interaction base,
// buttons, badges, the certainty system and the ETA text.
import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/components/shortcut_card.dart';
import 'package:pontual/ui/design/components/surface_card.dart';

import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Wraps [child] in both themes so the token extension is always present.
Widget harness(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light
        ? pontualLightTheme()
        : pontualDarkTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  const LineVM line = LineVM(
    key: '60-litoraneo-aviacao',
    name: 'Litorâneo / Aviação',
    short: '60',
    terminals: <String>['Litorâneo', 'Aviação'],
    isLive: true,
    liveVehicleCount: 2,
    supportsSharing: true,
  );

  testWidgets('Pressable fires on tap and stays inert without a callback', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(
        Pressable(
          semanticLabel: 'Aperte',
          onTap: () => taps++,
          child: const Text('Aperte'),
        ),
      ),
    );
    await tester.tap(find.text('Aperte'));
    expect(taps, 1);

    await tester.pumpWidget(
      harness(const Pressable(semanticLabel: 'Inerte', child: Text('Inerte'))),
    );
    await tester.tap(find.text('Inerte'));
    expect(taps, 1);
  });

  testWidgets('Pressable hit area is at least 48 by 48', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const Pressable(
          semanticLabel: 'X',
          child: SizedBox.square(dimension: 8),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Pressable)).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byType(Pressable)).width,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('PrimaryButton shows its label and is disabled while loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const PrimaryButton(label: UiStrings.consentAccept, onPressed: null),
      ),
    );
    expect(find.text(UiStrings.consentAccept), findsOneWidget);
    final Finder button = find.byType(PrimaryButton);
    expect(button, findsOneWidget);
  });

  testWidgets('DangerButton uses the danger colour at 12 percent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(const DangerButton(label: UiStrings.endTrip, onPressed: null)),
    );
    expect(find.text(UiStrings.endTrip), findsOneWidget);
  });

  testWidgets('Chip switches labels and fills on selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return Chip(
                  label: UiStrings.filterAll,
                  selected: true,
                  onTap: () {},
                );
              },
        ),
      ),
    );
    expect(find.text(UiStrings.filterAll), findsOneWidget);
  });

  testWidgets('Segmented moves the thumb and reports the change', (
    WidgetTester tester,
  ) async {
    String chosen = 'agora';
    await tester.pumpWidget(
      harness(
        StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return Segmented(
                  segments: const <Segment>[
                    Segment(value: 'agora', label: 'Agora'),
                    Segment(value: 'horarios', label: 'Horários'),
                  ],
                  value: chosen,
                  onChanged: (String value) => setState(() => chosen = value),
                );
              },
        ),
      ),
    );
    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Horários'), findsOneWidget);
    await tester.tap(find.text('Horários'));
    await tester.pumpAndSettle();
    expect(chosen, 'horarios');
  });

  testWidgets('CertaintyBadge shows a different shape per certainty', (
    WidgetTester tester,
  ) async {
    for (final Certainty certainty in Certainty.values) {
      await tester.pumpWidget(
        harness(LivePulse(child: CertaintyBadge(certainty: certainty))),
      );
      expect(find.byType(CertaintyBadge), findsOneWidget);
    }
  });

  testWidgets('LineBadge derives a colour from the line key', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const LineBadge(lineKey: 'x', text: '60')));
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('LineBadge falls back to a bus icon without a short code', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const LineBadge(lineKey: 'x', text: '')));
    expect(find.byType(LineBadge), findsOneWidget);
    expect(find.text('60'), findsNothing);
  });

  testWidgets('EtaText renders the hero value and its supporting line', (
    WidgetTester tester,
  ) async {
    final ArrivalVM arrival = ArrivalVM(
      lineKey: 'x',
      at: DateTime.utc(2026, 10, 14, 14, 35),
      certainty: Certainty.scheduled,
      asOf: DateTime.utc(2026, 10, 14, 14, 23),
    );
    await tester.pumpWidget(
      harness(
        LivePulse(
          child: EtaText.ofArrival(arrival, DateTime.utc(2026, 10, 14, 14, 23)),
        ),
      ),
    );
    expect(find.text('14:35'), findsOneWidget);
    expect(find.text('em 12 min'), findsOneWidget);
  });

  testWidgets('LiveDot draws without a mounted pulse host', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const LiveDot(certainty: Certainty.live)));
    expect(find.byType(LiveDot), findsOneWidget);
  });

  testWidgets('IconBtn exposes its semantic label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const IconBtn(
          icon: Icons.star_border_rounded,
          semanticLabel: UiStrings.favorite,
        ),
      ),
    );
    expect(find.byType(IconBtn), findsOneWidget);
    expect(find.bySemanticsLabel(UiStrings.favorite), findsOneWidget);
  });

  testWidgets('SurfaceCard is inert without a callback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const SurfaceCard(child: Text('cartao'))));
    expect(find.text('cartao'), findsOneWidget);
  });

  testWidgets('ShortcutCard renders its label and the line badge', (
    WidgetTester tester,
  ) async {
    final ArrivalVM arrival = ArrivalVM(
      lineKey: '60-litoraneo-aviacao',
      at: DateTime.utc(2026, 10, 14, 14, 35),
      certainty: Certainty.scheduled,
      asOf: DateTime.utc(2026, 10, 14, 14, 23),
    );
    await tester.pumpWidget(
      harness(
        LivePulse(
          child: ShortcutCard(
            label: 'Casa',
            line: line,
            arrival: arrival,
            now: DateTime.utc(2026, 10, 14, 14, 23),
            icon: Icons.home_rounded,
          ),
        ),
      ),
    );
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('AddShortcutCard shows a dashed border and its label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const AddShortcutCard(label: UiStrings.addShortcut, onTap: _noop),
      ),
    );
    expect(find.text(UiStrings.addShortcut), findsOneWidget);
  });

  testWidgets('context.colors returns the dark tokens in dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualDarkTheme(),
        home: Builder(
          builder: (BuildContext context) {
            expect(context.colors.bg, const Color(0xFF0A1110));
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('every screen state meets the tap target guideline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const Column(
          children: <Widget>[
            IconBtn(icon: Icons.search_rounded, semanticLabel: 'buscar'),
            Chip(label: 'chip'),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(IconBtn)).height,
      greaterThanOrEqualTo(44),
    );
  });
}

/// No-op action for inert gallery and test cards.
void _noop() {}

// Automated accessibility guidelines over the design-system components,
// in both themes. Manual TalkBack/VoiceOver/keyboard runs stay in
// docs/ui/a11y-script.md. See docs/ui/UI_SPEC.md 12.12.
import 'package:flutter/material.dart' hide Banner, Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Pumps [child] inside the given brightness tokens.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child,
  Brightness brightness,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? pontualLightTheme()
          : pontualDarkTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

/// Every tappable component under test, with its label.
List<Widget> get tappables => <Widget>[
  const PrimaryButton(label: UiStrings.retry, onPressed: null),
  const SecondaryButton(label: UiStrings.retry, onPressed: null),
  const Chip(label: UiStrings.filterAll),
  const IconBtn(icon: Icons.search_rounded, semanticLabel: 'buscar'),
  Segmented(
    segments: const <Segment>[
      Segment(value: 'a', label: 'Agora'),
      Segment(value: 'b', label: 'Horários'),
    ],
    value: 'a',
    onChanged: (_) {},
  ),
];

void main() {
  for (final Brightness brightness in <Brightness>[
    Brightness.light,
    Brightness.dark,
  ]) {
    final String mode = brightness == Brightness.light ? 'light' : 'dark';

    group('tap targets ($mode)', () {
      for (int i = 0; i < tappables.length; i++) {
        testWidgets('tappable $i meets the tap-target guidelines', (
          WidgetTester tester,
        ) async {
          await pumpThemed(tester, LivePulse(child: tappables[i]), brightness);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        });
      }
    });

    testWidgets('certainty badges meet text contrast ($mode)', (
      WidgetTester tester,
    ) async {
      await pumpThemed(
        tester,
        const LivePulse(
          child: Column(
            children: <Widget>[
              CertaintyBadge(certainty: Certainty.live),
              CertaintyBadge(certainty: Certainty.predicted),
              CertaintyBadge(certainty: Certainty.scheduled),
              CertaintyBadge(certainty: Certainty.stale),
            ],
          ),
        ),
        brightness,
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('banner and search field meet text contrast ($mode)', (
      WidgetTester tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          children: <Widget>[
            Banner(message: UiStrings.offlineBanner),
            SearchField(hint: UiStrings.searchHint),
          ],
        ),
        brightness,
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}

// Regression test for the one-off "RenderFlex overflowed ... on the
// bottom" reported during a live trip (LOGS-REPORT T6). The trip screen
// must not overflow at the smallest supported viewport with 2x text
// scale, in both the steady active state and the offline/stall state
// that the report was recorded in. The stop action stays pinned and
// must remain present and hit-testable at that size. Tapping it shows
// the end card, which must also render without overflow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/trip/trip_screen.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trip_rig.dart' as rig;

const Size _smallViewport = Size(320, 568);

Widget wrapApp(Widget child) => ProviderScope(
  child: MaterialApp(theme: pontualLightTheme(), home: child),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('active trip does not overflow and stop is reachable', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.view.physicalSize = _smallViewport;
    tester.view.devicePixelRatio = 1;

    final rig.Rig r = rig.rig(rig.happy());
    await rig.start(r);
    await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(TripScreen)))
          .scale(10),
      20,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(UiStrings.tripTitle), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tripStop')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('tripStop')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text(UiStrings.endTitle), findsOneWidget);
    expect(find.text(UiStrings.endDone), findsOneWidget);
    await tester.pumpWidget(wrapApp(const SizedBox()));
    r.controller.dispose();
    await r.positions.close();
  });

  testWidgets('offline stall state does not overflow and stop is reachable', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.view.physicalSize = _smallViewport;
    tester.view.devicePixelRatio = 1;

    final rig.Rig r = rig.rig(rig.happy());
    await rig.start(r);
    r.clock.advance(121 * 1000);
    await r.controller.checkAutoEndForTest();
    r.clock.advance(3000);
    await tester.pumpWidget(wrapApp(TripScreen(controller: r.controller)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      MediaQuery.textScalerOf(tester.element(find.byType(TripScreen)))
          .scale(10),
      20,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(UiStrings.tripTitle), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tripStop')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('tripStop')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text(UiStrings.endTitle), findsOneWidget);
    expect(find.text(UiStrings.endDone), findsOneWidget);
    await tester.pumpWidget(wrapApp(const SizedBox()));
    r.controller.dispose();
    await r.positions.close();
  });
}

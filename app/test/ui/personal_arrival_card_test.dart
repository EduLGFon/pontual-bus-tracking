import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pontual/ui/adapters/personal_arrival.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/features/line/personal_arrival_card.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

Widget harness(Widget child) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

PersonalArrivalVM readyVm({
  int stopDistanceM = 90,
  bool arriving = false,
  int minutes = 6,
  int sampleCount = 12,
  int confidence = 1,
}) {
  return PersonalArrivalVM(
    status: PersonalArrivalStatus.ready,
    stopDistanceM: stopDistanceM,
    lead: PersonalEtaVM(
      vehicleKey: 1,
      etaSeconds: arriving ? 30 : minutes * 60,
      minutes: minutes,
      arriving: arriving,
      passed: false,
      approaching: true,
      confidence: confidence,
      sampleCount: sampleCount,
      label: arriving
          ? UiStrings.myStopArrivingUntilYou
          : UiStrings.myStopEtaUntilYou(minutes),
      semantic: arriving
          ? UiStrings.myStopA11yArriving(stopDistanceM)
          : UiStrings.myStopA11y(minutes, stopDistanceM),
    ),
  );
}

void main() {
  testWidgets('ready shows copy and taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(), onTapLead: () => taps++)),
    );
    expect(find.text(UiStrings.myStopTitle), findsOneWidget);
    expect(find.text('~6 min'), findsOneWidget);
    expect(find.text(UiStrings.myStopEtaCaption), findsOneWidget);
    expect(find.text(UiStrings.confidenceLabel(1)), findsOneWidget);
    expect(find.text('Confiança média'), findsOneWidget);
    // predicted badge label
    await tester.tap(find.byType(PersonalArrivalCard));
    expect(taps, 1);
  });

  testWidgets('ready info sheet opens', (tester) async {
    await tester.pumpWidget(harness(PersonalArrivalCard(vm: readyVm())));
    await tester.tap(find.text(UiStrings.myStopHow));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.myStopInfoBody), findsOneWidget);
    expect(find.text(UiStrings.myStopInfoSample(12)), findsOneWidget);
  });

  testWidgets('info sheet no sample', (tester) async {
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(sampleCount: 0))),
    );
    await tester.tap(find.text(UiStrings.myStopHow));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.myStopInfoNoSample), findsOneWidget);
  });

  testWidgets('ready how does not fire onTapLead', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(), onTapLead: () => taps++)),
    );
    await tester.tap(find.text(UiStrings.myStopHow));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.myStopInfoBody), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets('prompt', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(
            status: PersonalArrivalStatus.needsLocation,
          ),
          onEnableLocation: () => taps++,
        ),
      ),
    );
    expect(find.text(UiStrings.myStopEnable), findsOneWidget);
    expect(find.text(UiStrings.myStopPrivacy), findsOneWidget);
    await tester.tap(find.text(UiStrings.myStopEnable));
    expect(taps, 1);
  });

  testWidgets('expired', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(
            status: PersonalArrivalStatus.needsLocation,
            staleFix: true,
          ),
          onRefresh: () => taps++,
        ),
      ),
    );
    expect(find.text(UiStrings.myStopExpired), findsOneWidget);
    expect(find.text(UiStrings.myStopRefresh), findsOneWidget);
    await tester.tap(find.text(UiStrings.myStopRefresh));
    expect(taps, 1);
  });

  for (final tc in <Map<String, dynamic>>[
    <String, dynamic>{
      'status': PersonalArrivalStatus.loadingStops,
      'copy': UiStrings.myStopLoading,
    },
    <String, dynamic>{
      'status': PersonalArrivalStatus.noStops,
      'copy': UiStrings.myStopNoStops,
    },
    <String, dynamic>{
      'status': PersonalArrivalStatus.noStopNear,
      'copy': UiStrings.myStopNoStopNear,
    },
  ]) {
    testWidgets('state ${tc['status']}', (tester) async {
      await tester.pumpWidget(
        harness(
          PersonalArrivalCard(
            vm: PersonalArrivalVM(
              status: tc['status'] as PersonalArrivalStatus,
            ),
          ),
        ),
      );
      expect(find.text(tc['copy'] as String), findsOneWidget);
    });
  }

  testWidgets('etaLoading', (tester) async {
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(
            status: PersonalArrivalStatus.etaLoading,
            stopDistanceM: 90,
          ),
        ),
      ),
    );
    expect(find.text(UiStrings.myStopCalculating), findsOneWidget);
  });

  testWidgets('etaError', (tester) async {
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(
            status: PersonalArrivalStatus.etaError,
            stopDistanceM: 90,
          ),
        ),
      ),
    );
    expect(find.text(UiStrings.myStopNoEstimate), findsOneWidget);
  });

  testWidgets('noApproaching', (tester) async {
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(
            status: PersonalArrivalStatus.noApproaching,
            stopDistanceM: 90,
          ),
        ),
      ),
    );
    expect(find.text(UiStrings.myStopNoApproaching), findsOneWidget);
  });

  testWidgets('noLive renders nothing', (tester) async {
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(status: PersonalArrivalStatus.noLive),
        ),
      ),
    );
    expect(find.byType(SurfaceCard), findsNothing);
  });

  testWidgets('ready far shows nearby title', (tester) async {
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(stopDistanceM: 220))),
    );
    expect(find.text(UiStrings.myStopNearby), findsOneWidget);
  });

  testWidgets('arriving shows Chegando', (tester) async {
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(arriving: true))),
    );
    expect(find.text(UiStrings.myStopArriving), findsOneWidget);
  });

  testWidgets('noStops refresh is discoverable and fires', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(status: PersonalArrivalStatus.noStops),
          onRefresh: () => taps++,
        ),
      ),
    );
    expect(find.text(UiStrings.myStopRefresh), findsOneWidget);
    await tester.tap(find.text(UiStrings.myStopRefresh));
    expect(taps, 1);
  });

  testWidgets('200 percent text scale no exception (ready)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualLightTheme(),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: PersonalArrivalCard(vm: readyVm()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('200 percent text scale no exception (prompt)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualLightTheme(),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: PersonalArrivalCard(
                vm: const PersonalArrivalVM(
                  status: PersonalArrivalStatus.needsLocation,
                ),
                onEnableLocation: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics one sentence ready', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(PersonalArrivalCard(vm: readyVm(), onTapLead: () {})),
    );
    final String sentence =
        '${UiStrings.certaintyPredicted}. ${UiStrings.myStopA11y(6, 90)}';
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics one sentence prompt', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(
            status: PersonalArrivalStatus.needsLocation,
          ),
          onEnableLocation: () {},
        ),
      ),
    );
    const String sentence =
        '${UiStrings.myStopEnable}. ${UiStrings.myStopPrivacy}';
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics one sentence expired', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(
            status: PersonalArrivalStatus.needsLocation,
            staleFix: true,
          ),
          onRefresh: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel(UiStrings.myStopExpired), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics one sentence noStops', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(status: PersonalArrivalStatus.noStops),
          onRefresh: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel(UiStrings.myStopNoStops), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics one sentence noStopNear', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(status: PersonalArrivalStatus.noStopNear),
          onRefresh: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel(UiStrings.myStopNoStopNear), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics one sentence etaError', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        PersonalArrivalCard(
          vm: const PersonalArrivalVM(
            status: PersonalArrivalStatus.etaError,
            stopDistanceM: 90,
          ),
          onRefresh: () {},
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(
        'Seu ponto. a 90 m de você. ${UiStrings.myStopNoEstimate}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('null distance ready', (tester) async {
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(
            status: PersonalArrivalStatus.ready,
            stopDistanceM: null,
            lead: PersonalEtaVM(
              vehicleKey: 1,
              etaSeconds: 360,
              minutes: 6,
              arriving: false,
              passed: false,
              approaching: true,
              confidence: 1,
              sampleCount: 0,
              label: '~6 min até você',
              semantic: '',
            ),
          ),
        ),
      ),
    );
    expect(find.text('a 0 m de você'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200 percent text scale no exception (degraded)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pontualLightTheme(),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: PersonalArrivalCard(
                vm: const PersonalArrivalVM(
                  status: PersonalArrivalStatus.etaError,
                  stopDistanceM: 90,
                ),
                onRefresh: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inert ready exposes sentence', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(PersonalArrivalCard(vm: readyVm())));
    final String sentence =
        '${UiStrings.certaintyPredicted}. ${UiStrings.myStopA11y(6, 90)}';
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
    handle.dispose();
  });

  testWidgets('inert prompt exposes sentence', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        const PersonalArrivalCard(
          vm: PersonalArrivalVM(
            status: PersonalArrivalStatus.needsLocation,
          ),
        ),
      ),
    );
    const String sentence =
        '${UiStrings.myStopEnable}. ${UiStrings.myStopPrivacy}';
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
    handle.dispose();
  });
}

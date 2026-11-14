// Widget tests for the shared line status line. Linhas and Busca render
// this widget, so every state keeps one wording and one style.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/design/components/line_status_line.dart';
import 'package:pontual/ui/design/theme/theme.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Themed shell for one status line.
Widget harness(Widget child) {
  return MaterialApp(
    theme: pontualLightTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders every status state', (WidgetTester tester) async {
    final Map<LineStatus, String> cases = <LineStatus, String>{
      const LineStatus.live(): UiStrings.certaintyLive,
      const LineStatus(kind: LineStatusKind.now, time: '10:00'):
          '${UiStrings.nextDeparture} 10:00 · agora',
      const LineStatus(
        kind: LineStatusKind.imminent,
        time: '10:05',
        minutes: 5,
      ): '${UiStrings.nextDeparture} 10:05 · em 5 min',
      const LineStatus(
        kind: LineStatusKind.upcoming,
        time: '10:20',
        minutes: 20,
      ): '${UiStrings.nextDeparture} 10:20 · em 20 min',
      const LineStatus(
        kind: LineStatusKind.upcoming,
        time: '11:20',
        minutes: 80,
      ): '${UiStrings.nextDeparture} 11:20 · em 1 h 20',
      const LineStatus(kind: LineStatusKind.tomorrow, time: '05:40'):
          UiStrings.homeTomorrowAt('05:40'),
      const LineStatus.noneToday(): UiStrings.homeNoMoreToday,
      const LineStatus.noTimetable(): UiStrings.linesNoTimetable,
    };
    for (final MapEntry<LineStatus, String> entry in cases.entries) {
      await tester.pumpWidget(harness(LineStatusLine(status: entry.key)));
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: entry.key.kind.name,
      );
    }
  });

  testWidgets('live status shows the count only above one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(const LineStatusLine(status: LineStatus.live())),
    );
    expect(find.text(UiStrings.certaintyLive), findsOneWidget);

    await tester.pumpWidget(
      harness(const LineStatusLine(status: LineStatus.live(), liveCount: 3)),
    );
    expect(find.text('${UiStrings.certaintyLive} · 3'), findsOneWidget);
  });
}

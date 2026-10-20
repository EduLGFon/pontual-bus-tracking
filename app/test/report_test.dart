// Passenger report parsing, age/count copy, and the calm chip strip.
// No network: pure models plus widget rendering.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/features/reports/report_chip.dart';
import 'package:pontual/ui/features/reports/report_sheet.dart';
import 'package:pontual/ui/features/reports/report_style.dart';
import 'package:pontual/ui/features/reports/report_strip.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

ReportVM report({
  ReportKind kind = ReportKind.broken,
  String? stop,
  int count = 1,
  int created = 120,
  int updated = 60,
  int expires = 600,
}) {
  return ReportVM(
    lineId: 7,
    kind: kind,
    stop: stop,
    count: count,
    createdAgeS: created,
    updatedAgeS: updated,
    expiresInS: expires,
  );
}

void main() {
  test('wire parsing keeps unknown kinds neutral and drops bad rows', () {
    final ReportDTO? known = ReportDTO.fromJson(<String, dynamic>{
      'kind': 'waiting',
      'stop': 's1',
      'count': 2,
      'created_age_s': 30,
      'updated_age_s': 5,
      'expires_in_s': 570,
    });
    expect(known?.kind, ReportKind.waiting);
    expect(known?.count, 2);

    final ReportDTO? unknown = ReportDTO.fromJson(<String, dynamic>{
      'kind': 'flood',
      'stop': null,
      'count': 1,
      'created_age_s': 1,
      'updated_age_s': 1,
      'expires_in_s': 100,
    });
    expect(unknown?.kind, ReportKind.unknown);
    expect(ReportDTO.fromJson(<String, dynamic>{'kind': 'broken'}), isNull);
    expect(
      parseReports(<Object?>[
        <String, dynamic>{
          'kind': 'waiting',
          'stop': 's1',
          'count': 2,
          'created_age_s': 30,
          'updated_age_s': 5,
          'expires_in_s': 570,
        },
        'bad',
      ]),
      hasLength(1),
    );
  });

  test('client report ages advance on the monotonic clock', () {
    const ClientReport r = ClientReport(
      kind: ReportKind.broken,
      stop: null,
      count: 1,
      createdAgeS: 10,
      updatedAgeS: 5,
      expiresInS: 100,
      receivedAtMs: 1000,
    );
    expect(r.createdAgeAt(1000), 10);
    expect(r.createdAgeAt(11000), 20);
    expect(r.updatedAgeAt(11000), 15);
    expect(r.expiresInAt(11000), 90);
    expect(r.expiresInAt(200000), 0);
  });

  test('copy is honest about single sources and privacy', () {
    expect(reportAgeLabel(10), UiStrings.reportAgeNow);
    expect(reportAgeLabel(120), 'há 2 min');
    expect(reportAgeLabel(7200), 'há 2 h');
    expect(
      reportChipLabel(report(kind: ReportKind.waiting, count: 1)),
      'Alguém esperando · há 1 min',
    );
    expect(
      reportChipLabel(report(kind: ReportKind.waiting, count: 3)),
      '3 esperando · há 1 min',
    );
    expect(
      reportChipLabel(report(kind: ReportKind.broken)),
      'Ônibus quebrado · há 1 min',
    );
    expect(
      reportCountLabel(report(kind: ReportKind.waiting, count: 1)),
      UiStrings.reportSomeoneWaiting,
    );
    expect(
      reportCountLabel(report(kind: ReportKind.broken, count: 1)),
      UiStrings.reportOneReport,
    );
    expect(
      reportCountLabel(report(kind: ReportKind.broken, count: 2)),
      '2 pessoas relataram',
    );
  });

  test('stop picker labels unnamed nodes with a local ordinal', () {
    const StopPoint named = StopPoint(
      id: 's1',
      lat: -18.72,
      lng: -39.85,
      name: 'Guriri',
    );
    const StopPoint unnamed = StopPoint(id: 's2', lat: -18.72, lng: -39.85);
    expect(stopPickerLabel(named, 0), 'Guriri');
    expect(stopPickerLabel(unnamed, 2), 'Ponto de ônibus 3');
  });

  testWidgets('strip shows two chips plus overflow and stays readable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final List<ReportVM> reports = <ReportVM>[
      report(kind: ReportKind.blocked, stop: 's1'),
      report(kind: ReportKind.broken),
      report(kind: ReportKind.waiting, stop: 's1', count: 3),
    ];
    int more = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: Scaffold(
            body: ReportStrip(
              reports: reports,
              onTap: (_) {},
              onMore: () => more += 1,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ReportChip), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('+1'));
    expect(more, 1);
  });

  testWidgets('report sheet renders the four kinds and the stop picker', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const List<StopPoint> stops = <StopPoint>[
      StopPoint(id: 's1', lat: -18.72, lng: -39.85, name: 'Guriri'),
      StopPoint(id: 's2', lat: -18.72, lng: -39.85),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showReportSheet(
                      context,
                      lineId: 7,
                      lineName: 'Sete / Centro',
                      stops: stops,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(UiStrings.reportSheetTitle), findsOneWidget);
    expect(find.text(UiStrings.reportWaiting), findsOneWidget);
    expect(find.text(UiStrings.reportFull), findsOneWidget);
    expect(find.text(UiStrings.reportBroken), findsOneWidget);
    expect(find.text(UiStrings.reportBlocked), findsOneWidget);
    expect(find.text(UiStrings.reportPrivacy), findsOneWidget);
    await tester.tap(find.text(UiStrings.reportWaiting));
    await tester.pumpAndSettle();
    expect(find.text('Guriri'), findsOneWidget);
    expect(find.text('Ponto de ônibus 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

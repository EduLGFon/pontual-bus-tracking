// Share progress tests: tracker behavior, controller phase reports,
// and the progress sheet UI. The details block carries error codes and
// counts only, never coordinates, tokens, or device ids.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/domain/trip/share_phases.dart';
import 'package:pontual/features/trip/share_progress_sheet.dart';
import 'package:pontual/features/trip/share_progress_tracker.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart';

ShareProgressTracker tracker({int nowMs = 100000}) {
  final int now = nowMs;
  return ShareProgressTracker(
    lineId: 60,
    consentVersion: 1,
    host: 'api.example',
    nowMs: () => now,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('tracker starts all pending with no failure', () {
    final ShareProgressTracker t = tracker();
    for (final SharePhase p in sharePhaseOrder) {
      expect(t.statuses[p], SharePhaseStatus.pending);
    }
    expect(t.hasFailure, isFalse);
    expect(t.allDone, isFalse);
    expect(t.errorCode, isNull);
    expect(t.cancelled, isFalse);
  });

  test('tracker records failure codes and retry resets', () {
    final ShareProgressTracker t = tracker();
    t.report(SharePhase.register, SharePhaseStatus.active);
    t.report(
      SharePhase.register,
      SharePhaseStatus.failed,
      errorCode: 'offline',
    );
    expect(t.hasFailure, isTrue);
    expect(t.errorCode, 'offline');
    t.nextAttempt();
    expect(t.hasFailure, isFalse);
    expect(t.errorCode, isNull);
    expect(t.attempt, 2);
    expect(t.statuses[SharePhase.register], SharePhaseStatus.pending);
  });

  test('tracker cancel sets the flag', () {
    final ShareProgressTracker t = tracker();
    t.cancel();
    expect(t.cancelled, isTrue);
  });

  test('happy start reports every phase done in order', () async {
    final Rig r = rig(happy());
    final List<String> events = <String>[];
    bool? started;
    unawaited(
      r.controller
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
            onPhase: (SharePhase p, SharePhaseStatus s, {String? errorCode}) {
              events.add('${p.name}:${s.name}');
            },
          )
          .then((bool v) => started = v),
    );
    for (int i = 0; i < 100 && started == null; i++) {
      r.positions.add(pos(8));
      await Future<void>.microtask(() {});
    }
    expect(started, isTrue);
    expect(events, <String>[
      'consent:active',
      'consent:done',
      'permission:active',
      'permission:done',
      'register:active',
      'register:done',
      'gps:active',
      'gps:done',
      'start:active',
      'start:done',
    ]);
    expect(r.controller.lastErrorCode, isNull);
    await r.positions.close();
    r.controller.dispose();
  });

  test('register failure reports the phase and code', () async {
    final MockClient client = MockClient((http.Request req) async {
      throw http.ClientException('unreachable');
    });
    final Rig r = rig(client);
    final List<String> events = <String>[];
    final bool started = await r.controller.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
      onPhase: (SharePhase p, SharePhaseStatus s, {String? errorCode}) {
        events.add('${p.name}:${s.name}:${errorCode ?? '-'}');
      },
    );
    expect(started, isFalse);
    expect(r.controller.failReason, StartFailure.offline);
    expect(r.controller.lastErrorCode, 'offline');
    expect(events.contains('register:failed:offline'), isTrue);
    expect(events.any((String e) => e.startsWith('gps:')), isFalse);
    await r.positions.close();
    r.controller.dispose();
  });

  test('gps timeout reports gps-timeout', () async {
    final Rig r = rig(happy());
    final List<String> events = <String>[];
    // No fixes fed: the wait expires.
    final bool started = await r.controller.startTrip(
      lineId: 7,
      lineLabel: '7',
      showConsent: () async => true,
      showPermissions: () async {},
      firstFixTimeout: const Duration(milliseconds: 50),
      onPhase: (SharePhase p, SharePhaseStatus s, {String? errorCode}) {
        events.add('${p.name}:${s.name}:${errorCode ?? '-'}');
      },
    );
    expect(started, isFalse);
    expect(r.controller.failReason, StartFailure.noGps);
    expect(events.contains('gps:failed:gps-timeout'), isTrue);
    await r.positions.close();
    r.controller.dispose();
  });

  test('cancel during the gps wait aborts the start', () async {
    final Rig r = rig(happy());
    bool? started;
    unawaited(
      r.controller
          .startTrip(
            lineId: 7,
            lineLabel: '7',
            showConsent: () async => true,
            showPermissions: () async {},
            firstFixTimeout: const Duration(seconds: 30),
          )
          .then((bool v) => started = v),
    );
    // Let the start reach the GPS wait, then cancel (closes the stream).
    for (int i = 0; i < 20 && started == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    r.controller.cancelStart();
    for (int i = 0; i < 50 && started == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(started, isFalse);
    expect(r.controller.failReason, StartFailure.declined);
    await r.positions.close();
    r.controller.dispose();
  });

  testWidgets('sheet shows failure plus technical details', (
    WidgetTester tester,
  ) async {
    final ShareProgressTracker t = tracker();
    for (final SharePhase p in <SharePhase>[
      SharePhase.services,
      SharePhase.config,
      SharePhase.consent,
      SharePhase.permission,
    ]) {
      t.report(p, SharePhaseStatus.done);
    }
    t.report(SharePhase.register, SharePhaseStatus.done);
    t.report(SharePhase.gps, SharePhaseStatus.failed, errorCode: 'gps-timeout');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareProgressSheet(
            tracker: t,
            lineLabel: 'Litoraneo',
            onCancel: () {},
            onRetry: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Iniciando viagem'), findsWidgets);
    expect(find.text('Aguardando GPS'), findsOneWidget);
    // Friendly message for the GPS failure.
    expect(find.textContaining('localiza'), findsWidgets);
    // Retry and close actions on failure.
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
    // Details carry codes only, never coordinates or tokens.
    await tester.tap(find.text('Detalhes técnicos'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('gps-timeout'), findsOneWidget);
    expect(find.textContaining('linha: 60'), findsOneWidget);
    expect(find.textContaining('bm1_'), findsNothing);
    expect(find.textContaining('-18.7'), findsNothing);
    expect(find.textContaining('-39.8'), findsNothing);
  });

  testWidgets('sheet shows cancel while running', (WidgetTester tester) async {
    final ShareProgressTracker t = tracker();
    t.report(SharePhase.services, SharePhaseStatus.done);
    t.report(SharePhase.config, SharePhaseStatus.done);
    t.report(SharePhase.consent, SharePhaseStatus.done);
    t.report(SharePhase.permission, SharePhaseStatus.done);
    t.report(SharePhase.register, SharePhaseStatus.active);
    bool cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareProgressSheet(
            tracker: t,
            lineLabel: 'Litoraneo',
            onCancel: () => cancelled = true,
            onRetry: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cancelar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(cancelled, isTrue);
  });
}

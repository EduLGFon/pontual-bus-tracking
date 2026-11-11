import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pontual/core/diagnostics/diagnostics_uploader.dart';
import 'package:pontual/core/logging/log.dart';
import 'package:pontual/data/config/remote_config.dart' show appVersion;

void main() {
  group('DiagnosticsUploader', () {
    test('body carries real metadata, id and crash; no PII fields', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{
            'l': 'w',
            'm': 'msg',
            'c': 'ctx',
            't': 123,
          }),
        ],
        'diag_crash_v1': 'boom',
      });
      Map<String, dynamic>? captured;
      final MockClient client2 = MockClient((http.Request req) async {
        captured = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('', 204);
      });
      await DiagnosticsUploader(client: client2).uploadIfOptedIn(true);

      expect(captured, isNotNull);
      expect(captured!['build'], appVersion);
      expect((captured!['platform'] as String).length, lessThanOrEqualTo(20));
      expect((captured!['os'] as String).length, lessThanOrEqualTo(60));
      final String id = captured!['id'] as String;
      expect(id.length, 36);
      expect(captured!['crash'], 'boom');
      expect(captured!.containsKey('model'), isFalse);
      // No PII-ish fields.
      for (final String forbidden in <String>[
        'lat',
        'lng',
        'coordinate',
        'token',
        'sessionId',
        'deviceId',
        'userId',
      ]) {
        expect(captured!.containsKey(forbidden), isFalse);
      }
    });

    test('two failed uploads send the same id', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg'}),
        ],
      });
      final List<String> ids = <String>[];
      final MockClient client = MockClient((http.Request req) async {
        ids.add((jsonDecode(req.body) as Map<String, dynamic>)['id'] as String);
        return http.Response('', 500);
      });
      await DiagnosticsUploader(client: client).uploadIfOptedIn(true);
      await DiagnosticsUploader(client: client).uploadIfOptedIn(true);
      expect(ids.length, 2);
      expect(ids[0], ids[1]);
    });

    test('new batch after success sends a different id', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg1'}),
        ],
      });
      final List<String> ids = <String>[];
      final MockClient okClient = MockClient((http.Request req) async {
        ids.add((jsonDecode(req.body) as Map<String, dynamic>)['id'] as String);
        return http.Response('', 204);
      });
      await DiagnosticsUploader(client: okClient).uploadIfOptedIn(true);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg2'}),
        ],
      });
      final MockClient client2 = MockClient((http.Request req) async {
        ids.add((jsonDecode(req.body) as Map<String, dynamic>)['id'] as String);
        return http.Response('', 204);
      });
      await DiagnosticsUploader(client: client2).uploadIfOptedIn(true);

      expect(ids.length, 2);
      expect(ids[0], isNot(ids[1]));
    });

    test('record appended during upload survives success', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'before'}),
        ],
      });
      final Completer<void> gate = Completer<void>();
      final MockClient client = MockClient((http.Request req) async {
        await gate.future;
        return http.Response('', 204);
      });
      final Future<void> upload = DiagnosticsUploader(client: client)
          .uploadIfOptedIn(true);
      // Let the uploader read its snapshot.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      Log.w('during');
      await Log.flushPersistForTest();
      gate.complete();
      await upload;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList('diag_logs_v1')!;
      expect(raw.length, 1);
      expect((jsonDecode(raw.first) as Map<String, dynamic>)['m'], 'during');
    });

    test('crash replaced during upload survives success', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg'}),
        ],
        'diag_crash_v1': 'old',
      });
      final Completer<void> gate = Completer<void>();
      final MockClient client = MockClient((http.Request req) async {
        await gate.future;
        return http.Response('', 204);
      });
      final Future<void> upload = DiagnosticsUploader(client: client)
          .uploadIfOptedIn(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await DiagnosticsUploader.persistCrash('new');
      gate.complete();
      await upload;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('diag_crash_v1'), 'new');
    });

    test('blank build falls back to unknown', () {
      expect(DiagnosticsUploader.buildValue(''), 'unknown');
      expect(DiagnosticsUploader.buildValue('   '), 'unknown');
      expect(DiagnosticsUploader.buildValue('1.2.3'), '1.2.3');
    });

    test('clears records and crash only on success', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg'}),
        ],
        'diag_crash_v1': 'boom',
      });
      final MockClient failClient = MockClient(
        (_) async => http.Response('', 500),
      );
      await DiagnosticsUploader(client: failClient).uploadIfOptedIn(true);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('diag_logs_v1'), isNotNull);
      expect(prefs.getString('diag_crash_v1'), 'boom');

      SharedPreferences.setMockInitialValues(<String, Object>{
        'diag_logs_v1': <String>[
          jsonEncode(<String, dynamic>{'l': 'w', 'm': 'msg'}),
        ],
        'diag_crash_v1': 'boom',
      });
      final MockClient okClient = MockClient(
        (_) async => http.Response('', 204),
      );
      await DiagnosticsUploader(client: okClient).uploadIfOptedIn(true);
      final SharedPreferences prefs2 = await SharedPreferences.getInstance();
      expect(prefs2.getStringList('diag_logs_v1'), isNull);
      expect(prefs2.getString('diag_crash_v1'), isNull);
    });
  });

  group('Log persist', () {
    test('50 rapid warnings persist in order', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      Log.clearForTest();
      for (int i = 0; i < 50; i++) {
        Log.w('w$i');
      }
      await Log.flushPersistForTest();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList('diag_logs_v1')!;
      expect(raw.length, 50);
      for (int i = 0; i < 50; i++) {
        final Map<String, dynamic> r =
            jsonDecode(raw[i]) as Map<String, dynamic>;
        expect(r['m'], 'w$i');
      }
    });
  });

  group('FlutterError handling', () {
    test('stores context and stack truncated to 4000', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final String bigStack = 'S' * 5000;
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: Exception('boom'),
        stack: StackTrace.fromString(bigStack),
        context: ErrorDescription('building Foo'),
      );
      await DiagnosticsUploader.recordFlutterError(details);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String stored = prefs.getString('diag_crash_v1')!;
      expect(stored.length, lessThanOrEqualTo(4000));
      expect(stored, contains('Exception: boom'));
      expect(stored, contains('building Foo'));
      expect(stored, contains('S'));
    });
  });
}

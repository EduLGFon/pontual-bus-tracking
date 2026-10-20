// End-to-end sheet flow: a waiting report reads one fix, converts it to a
// coarse cell and sends only that cell. No coordinates on the wire.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/prefs/report_location_notice.dart';
import 'package:pontual/features/reports/report_location.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/ui/features/reports/report_sheet.dart';
import 'package:pontual/ui/features/reports/reports_providers.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGateway implements PermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.granted;

  @override
  Future<bool> servicesOn() async => true;

  @override
  Future<bool> preciseAccuracy() async => true;

  @override
  Future<void> openSettings() async {}
}

void main() {
  testWidgets('waiting report sends a coarse area and no coordinates', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      reportLocationNoticeKey: true,
    });
    late http.Request seen;
    final MockClient client = MockClient((http.Request req) async {
      seen = req;
      return http.Response(
        jsonEncode(<String, dynamic>{
          't': 100,
          'r': <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'waiting',
              'area': 'g52902_98514',
              'count': 1,
              'created_age_s': 0,
              'updated_age_s': 0,
              'expires_in_s': 600,
            },
          ],
        }),
        201,
      );
    });
    final BusApi api = BusApi(
      client: client,
      baseUrl: () => 'http://127.0.0.1:8080',
      readToken: () async => 'bm1_t',
      writeToken: (_) async {},
    );
    final ReportLocationService location = ReportLocationService(
      gateway: FakeGateway(),
      readFix: () async => (lat: -18.7156, lng: -39.8568, accuracyM: 20.0),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          busApiProvider.overrideWithValue(api),
          reportLocationServiceProvider.overrideWithValue(location),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showReportSheet(
                    context,
                    lineId: 7,
                    lineName: 'Sete / Centro',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UiStrings.reportWaiting));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(UiStrings.reportSubmit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UiStrings.reportSubmit));
    await tester.pumpAndSettle();

    final Map<String, dynamic> body =
        jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['kind'], 'waiting');
    expect(body['line'], 7);
    expect(body['area'], 'g52902_98514');
    expect(body.containsKey('lat'), isFalse);
    expect(body.containsKey('lng'), isFalse);
    expect(body.containsKey('acc'), isFalse);
    expect(body.containsKey('at'), isFalse);
    // Let the success toast timer expire before the test ends.
    await tester.pump(const Duration(seconds: 4));
  });
}

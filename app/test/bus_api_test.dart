// T20/T21 tests: lazy registration, token reuse, typed wrappers and
// error mapping on fakes, plus a real contract test against the local
// server when BUS_API_BASE is set. Merged into one file so the suite
// pays a single test-process startup instead of two.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/net/http_client.dart';
import 'package:pontual/domain/reporting/report_kind.dart';

BusApi fakeApi(MockClient client) {
  return BusApi(
    client: client,
    baseUrl: () => 'http://127.0.0.1:8080',
    readToken: () async => 'bm1_t',
    writeToken: (_) async {},
  );
}

void main() {
  group('registration', () {
    test('constructing the API performs no requests', () async {
      int calls = 0;
      final MockClient client = MockClient((_) async {
        calls += 1;
        return http.Response('{}', 201);
      });
      BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => null,
        writeToken: (_) async {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    });

    test('registers once then reuses the stored token', () async {
      int calls = 0;
      String? stored;
      final MockClient client = MockClient((_) async {
        calls += 1;
        return http.Response('{"token":"bm1_x","exp":1,"id":"d"}', 201);
      });
      final BusApi api = BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => stored,
        writeToken: (String t) async => stored = t,
      );
      final Result<String> first = await api.ensureRegistered();
      final Result<String> second = await api.ensureRegistered();
      expect(calls, 1);
      expect(stored, 'bm1_x');
      expect(first, isA<Ok<String>>());
      expect(second, isA<Ok<String>>());
    });

    test('server errors map to failures', () async {
      final MockClient client = MockClient((_) async {
        return http.Response('{"e":"rate"}', 429);
      });
      final BusApi api = BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => null,
        writeToken: (_) async {},
      );
      final Result<String> result = await api.ensureRegistered();
      expect(result, isA<Err<String>>());
    });

    test('vehicle snapshots use etag then serve 304 from cache', () async {
      final List<String?> seenIfNoneMatch = <String?>[];
      int calls = 0;
      final MockClient client = MockClient((http.Request req) async {
        calls += 1;
        seenIfNoneMatch.add(req.headers['if-none-match']);
        if (calls == 1) {
          return http.Response(
            '{"t":100,"v":[[3,-18.72,-39.85,90,29,1,4]]}',
            200,
            headers: <String, String>{'ETag': 'W/"a-1"'},
          );
        }
        return http.Response('', 304);
      });
      final BusApi api = BusApi(
        client: client,
        baseUrl: () => 'http://127.0.0.1:8080',
        readToken: () async => null,
        writeToken: (_) async {},
      );
      final Result<VehiclesSnapshot> first = await api.getVehicles(7);
      final Result<VehiclesSnapshot> second = await api.getVehicles(7);
      expect(calls, 2);
      expect(seenIfNoneMatch[0], isNull);
      expect(seenIfNoneMatch[1], 'W/"a-1"');
      expect((first as Ok<VehiclesSnapshot>).value.epochS, 100);
      expect((second as Ok<VehiclesSnapshot>).value.vehicles.length, 1);
    });

    test('shared client factory builds without network', () {
      final http.Client client = createHttpClient();
      client.close();
    });
  });

  group('typed wrappers', () {
    test('consents maps ok and consent errors', () async {
      final MockClient ok = MockClient((_) async {
        return http.Response('{"ok":true}', 200);
      });
      expect(await fakeApi(ok).postConsents('bm1_t', 1), isA<Ok<bool>>());

      final MockClient denied = MockClient((_) async {
        return http.Response('{"e":"consent"}', 403);
      });
      final Result<bool> res = await fakeApi(denied).postConsents('bm1_t', 9);
      expect((res as Err<bool>).failure, isA<ServerFailure>());
      expect((res.failure as ServerFailure).code, 'consent');
    });

    test('start maps instruction and line errors', () async {
      final MockClient ok = MockClient((_) async {
        return http.Response('{"r":"W","n":20}', 201);
      });
      final Result<TripInstruction> res = await fakeApi(ok).startTrip(
        'bm1_t',
        lineId: 7,
        lat: -18.72,
        lng: -39.85,
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
      );
      expect((res as Ok<TripInstruction>).value.role, 'W');

      final MockClient missing = MockClient((_) async {
        return http.Response('{"e":"line"}', 404);
      });
      final Result<TripInstruction> gone = await fakeApi(missing).startTrip(
        'bm1_t',
        lineId: 999,
        lat: -18.72,
        lng: -39.85,
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
      );
      expect(
        ((gone as Err<TripInstruction>).failure as ServerFailure).code,
        'line',
      );
    });

    test('ping maps instruction, end codes, and auth', () async {
      Future<Result<TripInstruction>> ping(MockClient c) {
        return fakeApi(c).pingTrip(
          'bm1_t',
          seq: 1,
          lat: -18.72,
          lng: -39.85,
          speedMps: 8,
          heading: 90,
          accuracyM: 10,
          batteryPct: 80,
          charging: false,
          role: 'W',
        );
      }

      final MockClient ok = MockClient((_) async {
        return http.Response('{"r":"L","n":15}', 200);
      });
      expect((await ping(ok) as Ok<TripInstruction>).value.intervalS, 15);

      final MockClient ended = MockClient((_) async {
        return http.Response('{"r":"W","n":20,"e":"abuse"}', 200);
      });
      expect((await ping(ended) as Ok<TripInstruction>).value.end, 'abuse');

      final MockClient auth = MockClient((_) async {
        return http.Response('{"e":"auth"}', 401);
      });
      expect(
        ((await ping(auth) as Err<TripInstruction>).failure as ServerFailure)
            .code,
        'auth',
      );
    });

    test('end and delete map empty success', () async {
      final MockClient ok = MockClient((_) async {
        return http.Response('', 204);
      });
      expect(await fakeApi(ok).endTrip('bm1_t'), isA<Ok<bool>>());
      expect(await fakeApi(ok).deleteMe('bm1_t'), isA<Ok<bool>>());
    });

    test('vehicles and live parse, including optional reports', () async {
      final MockClient client = MockClient((http.Request req) async {
        if (req.url.path.endsWith('/vehicles')) {
          return http.Response(
            '{"t":100,"v":[[7,-18.72,-39.85,90,29,1,4]],'
            '"r":[{"kind":"broken","stop":null,"count":2,'
            '"created_age_s":120,"updated_age_s":10,"expires_in_s":1700}]}',
            200,
          );
        }
        return http.Response('[[7,1]]', 200);
      });
      final BusApi api = fakeApi(client);
      final VehiclesSnapshot snap =
          (await api.getVehicles(7) as Ok<VehiclesSnapshot>).value;
      expect(snap.epochS, 100);
      expect(snap.vehicles.first[0], 7);
      expect(snap.reports, hasLength(1));
      expect(snap.reports.first.kind, ReportKind.broken);
      expect(snap.reports.first.count, 2);
      final LiveLines live = (await api.getLive() as Ok<LiveLines>).value;
      expect(live.rows, [
        [7, 1],
      ]);
    });

    test('postReport sends no coordinates and parses the snapshot', () async {
      late http.Request seen;
      final MockClient client = MockClient((http.Request req) async {
        seen = req;
        return http.Response(
          '{"t":100,"r":[{"kind":"waiting","stop":"s1","count":1,'
          '"created_age_s":0,"updated_age_s":0,"expires_in_s":600}]}',
          201,
        );
      });
      final Result<List<ReportDTO>> result = await fakeApi(client).postReport(
        'bm1_t',
        op: 'report',
        kind: ReportKind.waiting,
        lineId: 7,
        stop: 's1',
      );
      expect(result, isA<Ok<List<ReportDTO>>>());
      final List<ReportDTO> reports = (result as Ok<List<ReportDTO>>).value;
      expect(reports.single.stop, 's1');
      final Map<String, dynamic> body =
          jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['op'], 'report');
      expect(body['kind'], 'waiting');
      expect(body['line'], 7);
      expect(body['stop'], 's1');
      expect(body.containsKey('lat'), isFalse);
      expect(body.containsKey('at'), isFalse);
    });

    test('real contract against local server', () async {
      if (kIsWeb) {
        markTestSkipped('live contract needs dart:io env on the VM');
        return;
      }
      final String? base = Platform.environment['BUS_API_BASE'];
      if (base == null || base.isEmpty) {
        markTestSkipped('set BUS_API_BASE to run the live contract');
        return;
      }
      final BusApi api = BusApi(
        client: http.Client(),
        baseUrl: () => base,
        readToken: () async => null,
        writeToken: (_) async {},
      );
      final Ok<String> reg = await api.ensureRegistered() as Ok<String>;
      expect(reg.value.startsWith('bm1_'), isTrue);
      expect(await api.postConsents(reg.value, 1), isA<Ok<bool>>());
      final Ok<TripInstruction> started = await api.startTrip(
        reg.value,
        // CI seeds the server with a synthetic line 7 (LINES_JSON); the real
        // bundle has official line numbers, so pass --dart-define=BUS_API_LINE=60
        // when running against bundle data.
        lineId: const int.fromEnvironment('BUS_API_LINE', defaultValue: 7),
        lat: -18.72,
        lng: -39.85,
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
      ) as Ok<TripInstruction>;
      expect(started.value.role, 'W');
      final Ok<TripInstruction> pinged = await api.pingTrip(
        reg.value,
        seq: 1,
        lat: -18.72,
        lng: -39.85,
        speedMps: 8,
        heading: 90,
        accuracyM: 10,
        batteryPct: 80,
        charging: false,
        role: 'W',
      ) as Ok<TripInstruction>;
      expect(pinged.value.role, isNotEmpty);
      expect(await api.endTrip(reg.value), isA<Ok<bool>>());
      expect(await api.deleteMe(reg.value), isA<Ok<bool>>());
      api.client.close();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

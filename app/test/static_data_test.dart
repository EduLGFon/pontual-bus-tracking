// T22 tests: bundle first, cache, conditional GET, atomic swap.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String bundleManifest = '{"data_version":"b1","lines":"lines.b1.json"}';
const String bundleLines =
    '[{"id":7,"code":"seven","short":"7","name":"Seven","pilot":true,"schedules":[]}]';
const String remoteManifest = '{"data_version":"b2","lines":"lines.b2.json"}';
const String remoteLines =
    '[{"id":7,"code":"seven","short":"7","name":"Seven v2","pilot":true,"schedules":[]}]';

int nowMs = 0;

StaticDataRepository repo(MockClient client) {
  return StaticDataRepository(
    client: client,
    staticBaseUrl: () => 'https://static.example',
    bundleManifestJson: bundleManifest,
    bundleLinesJson: bundleLines,
    prefs: SharedPreferences.getInstance,
    nowMs: () => nowMs,
  );
}

void main() {
  setUp(() {
    nowMs = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('offline first run shows bundled lines', () async {
    final MockClient client = MockClient((_) async {
      throw StateError('no network on first paint');
    });
    final List<StaticLine> lines = await repo(client).lines();
    expect(lines.length, 1);
    expect(lines.first.name, 'Seven');
  });

  test('304 keeps cached data', () async {
    final StaticDataRepository r = repo(
      MockClient((_) async {
        return http.Response('', 304);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    expect(await r.refresh(), isA<Ok<bool>>());
    expect(true, isTrue);
    expect((await r.lines()).first.name, 'Seven');
  });

  test('newer remote swaps atomically', () async {
    final StaticDataRepository r = repo(
      MockClient((http.Request req) async {
        if (req.url.path.endsWith('manifest.json')) {
          return http.Response(
            remoteManifest,
            200,
            headers: <String, String>{'etag': 'e2'},
          );
        }
        return http.Response(remoteLines, 200);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    expect(((await r.refresh()) as Ok<bool>).value, isTrue);
    expect((await r.lines()).first.name, 'Seven v2');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('static_manifest'), remoteManifest);
  });

  test('swap evicts superseded bundles', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('static_lines_b1', bundleLines);
    final StaticDataRepository r = repo(
      MockClient((http.Request req) async {
        if (req.url.path.endsWith('manifest.json')) {
          return http.Response(
            remoteManifest,
            200,
            headers: <String, String>{'ETag': 'e2'},
          );
        }
        return http.Response(remoteLines, 200);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    expect(((await r.refresh()) as Ok<bool>).value, isTrue);
    expect((await r.lines()).first.name, 'Seven v2');
    expect(prefs.getString('static_lines_b1'), isNull);
    expect(prefs.getString('static_lines_b2'), remoteLines);
  });

  test('corrupt remote keeps old data', () async {
    final StaticDataRepository r = repo(
      MockClient((_) async {
        return http.Response('not json', 200);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    expect(await r.refresh(), isA<Err<bool>>());
    expect((await r.lines()).first.name, 'Seven');
  });

  test('checks at most once per day', () async {
    int calls = 0;
    final StaticDataRepository r = repo(
      MockClient((_) async {
        calls += 1;
        return http.Response('', 304);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    await r.refresh();
    await r.refresh();
    expect(calls, 1);
  });

  test('manifest version parses', () {
    final Map<String, dynamic> manifest =
        jsonDecode(bundleManifest) as Map<String, dynamic>;
    expect(manifest['data_version'], 'b1');
  });

  test('bundled stops load offline', () async {
    final StaticDataRepository r = StaticDataRepository(
      client: MockClient((_) async {
        throw StateError('offline');
      }),
      staticBaseUrl: () => 'https://static.example',
      bundleManifestJson: '{"data_version":"b1","lines":"lines.b1.json","stops":"stops.s1.json"}',
      bundleLinesJson: bundleLines,
      bundleStopsJson: '[{"id":"s1","lat":-18.72,"lng":-39.85,"src":"osm"}]',
      prefs: SharedPreferences.getInstance,
      nowMs: () => nowMs,
    );
    final List<StopPoint> stops = await r.stops();
    expect(stops.length, 1);
    expect(stops.first.id, 's1');
  });

  test('corrupt stops yield empty, lines keep working', () async {
    final StaticDataRepository r = StaticDataRepository(
      client: MockClient((_) async {
        throw StateError('offline');
      }),
      staticBaseUrl: () => 'https://static.example',
      bundleManifestJson: bundleManifest,
      bundleLinesJson: bundleLines,
      bundleStopsJson: 'not json',
      prefs: SharedPreferences.getInstance,
      nowMs: () => nowMs,
    );
    expect(await r.stops(), isEmpty);
    expect((await r.lines()).first.name, 'Seven');
  });

  test('newer remote swaps stops with lines', () async {
    const String manifest2 =
        '{"data_version":"b2","lines":"lines.b2.json","stops":"stops.s2.json"}';
    const String stops2 =
        '[{"id":"s2","name":"Centro","lat":-18.71,"lng":-39.86,"src":"survey"}]';
    final StaticDataRepository r = repo(
      MockClient((http.Request req) async {
        if (req.url.path.endsWith('manifest.json')) {
          return http.Response(manifest2, 200);
        }
        if (req.url.path.contains('stops')) {
          return http.Response(stops2, 200);
        }
        return http.Response(remoteLines, 200);
      }),
    );
    nowMs = checkInterval.inMilliseconds + 1;
    expect(((await r.refresh()) as Ok<bool>).value, isTrue);
    final List<StopPoint> stops = await r.stops();
    expect(stops.length, 1);
    expect(stops.first.name, 'Centro');
  });
}

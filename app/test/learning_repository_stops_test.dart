// Repository tests for the global stops and stop arrivals endpoints.
// MockClient keeps every request local.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/learning/learning_repository.dart';
import 'package:pontual/domain/learning/global_stop.dart';

LearningRepository _repo(MockClient client) {
  return LearningRepository(client: client, baseUrl: () => 'https://api.test');
}

void main() {
  test('fetchAllStops parses contract keys and unknown entries', () async {
    final LearningRepository repo = _repo(
      MockClient((http.Request request) async {
        expect(request.url.toString(), 'https://api.test/v1/stops');
        return http.Response(
          '{"v":1,"stops":[{"id":"s1","lat":-18.72,"lng":-39.85,'
          '"r":25,"n":12,"name":"Centro","lines":[{"l":66,"d":0,'
          '"s":"member-1"}]},{"id":"s2","lat":-18.73,"lng":-39.86,'
          '"extra":true}]}',
          200,
        );
      }),
    );
    final Result<List<GlobalStop>?> result = await repo.fetchAllStops();
    expect(result, isA<Ok<List<GlobalStop>?>>());
    final List<GlobalStop> stops = (result as Ok<List<GlobalStop>?>).value!;
    expect(stops.length, 2);
    expect(stops.first.id, 's1');
    expect(stops.first.name, 'Centro');
    expect(stops.first.lines.single.lineId, 66);
    expect(stops.last.radiusM, 30);
    expect(stops.last.lines, isEmpty);
  });

  test('fetchAllStops skips missing ids and null-island coordinates', () async {
    final LearningRepository repo = _repo(
      MockClient((_) async {
        return http.Response(
          '{"stops":[{"lat":-18.72,"lng":-39.85},'
          '{"id":"null-island","lat":0,"lng":0},'
          '{"id":"good","lat":-18.72,"lng":-39.85}]}',
          200,
        );
      }),
    );
    final Result<List<GlobalStop>?> result = await repo.fetchAllStops();
    final List<GlobalStop> stops = (result as Ok<List<GlobalStop>?>).value!;
    expect(stops.length, 1);
    expect(stops.single.id, 'good');
  });

  test('fetchAllStops returns null on 404 and Err on server failure', () async {
    final LearningRepository missing = _repo(
      MockClient((_) async => http.Response('', 404)),
    );
    final Result<List<GlobalStop>?> notFound = await missing.fetchAllStops();
    expect(notFound, isA<Ok<List<GlobalStop>?>>());
    expect((notFound as Ok<List<GlobalStop>?>).value, isNull);

    final LearningRepository failed = _repo(
      MockClient((_) async => http.Response('', 500)),
    );
    expect(await failed.fetchAllStops(), isA<Err<List<GlobalStop>?>>());
  });

  test('fetchStopArrivals parses items and returns null on 404', () async {
    final LearningRepository repo = _repo(
      MockClient((http.Request request) async {
        expect(
          request.url.toString(),
          'https://api.test/v1/stops/stop-1/arrivals',
        );
        return http.Response(
          '{"id":"stop-1","now":1730000000,"items":[{"line":66,'
          '"code":"66-centro-ifes-ufes","vehicle":12,"eta_s":240,'
          '"conf":"high","n":38,"m":"learned"}]}',
          200,
        );
      }),
    );
    final Result<StopArrivals?> result = await repo.fetchStopArrivals('stop-1');
    expect(result, isA<Ok<StopArrivals?>>());
    final StopArrivals arrivals = (result as Ok<StopArrivals?>).value!;
    expect(arrivals.stopId, 'stop-1');
    expect(arrivals.nowS, 1730000000);
    expect(arrivals.items.single.lineId, 66);
    expect(arrivals.items.single.etaS, 240);
    expect(arrivals.items.single.method, 'learned');

    final LearningRepository missing = _repo(
      MockClient((_) async => http.Response('', 404)),
    );
    final Result<StopArrivals?> notFound = await missing.fetchStopArrivals(
      'stop-1',
    );
    expect(notFound, isA<Ok<StopArrivals?>>());
    expect((notFound as Ok<StopArrivals?>).value, isNull);
  });

  test('fetchStopArrivals never throws on malformed JSON', () async {
    final LearningRepository repo = _repo(
      MockClient((_) async => http.Response('not-json', 200)),
    );
    expect(await repo.fetchStopArrivals('stop-1'), isA<Err<StopArrivals?>>());
  });

  test('fetchAllStops never throws on a bad stops value', () async {
    final LearningRepository repo = _repo(
      MockClient((_) async => http.Response('{"stops":"not-a-list"}', 200)),
    );
    final Result<List<GlobalStop>?> result = await repo.fetchAllStops();
    expect(result, isA<Ok<List<GlobalStop>?>>());
    expect((result as Ok<List<GlobalStop>?>).value, isEmpty);
  });
}

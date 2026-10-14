// Live-lines last-good cache: a failed /v1/live poll keeps the previous
// dots instead of blanking every live badge until the next 30 s tick.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/api/dto.dart';

void main() {
  test('a failed live poll keeps the last good dots', () async {
    int calls = 0;
    final BusApi api = BusApi(
      client: MockClient((http.Request req) async {
        calls += 1;
        if (calls == 1) {
          return http.Response('[[60,2]]', 200);
        }
        return http.Response('{}', 500);
      }),
      baseUrl: () => 'http://127.0.0.1:8080',
      readToken: () async => null,
      writeToken: (_) async {},
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[busApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final LiveLines first = await container.read(liveProvider.future);
    expect(first.rows, <List<int>>[
      <int>[60, 2],
    ]);

    container.invalidate(liveProvider);
    final LiveLines second = await container.read(liveProvider.future);
    expect(calls, 2);
    expect(second.rows, <List<int>>[
      <int>[60, 2],
    ]);
  });

  test('live starts empty with no good poll yet', () async {
    final BusApi api = BusApi(
      client: MockClient((_) async => http.Response('{}', 500)),
      baseUrl: () => 'http://127.0.0.1:8080',
      readToken: () async => null,
      writeToken: (_) async {},
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[busApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final LiveLines live = await container.read(liveProvider.future);
    expect(live.rows, isEmpty);
  });
}

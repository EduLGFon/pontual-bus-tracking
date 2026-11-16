// Provider tests for global stops caching and stop arrival failures.
// No real network or asset access.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/learning/learning_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/learning/global_stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLearningRepository extends LearningRepository {
  _FakeLearningRepository(this.result)
    : super(
        client: MockClient((_) async => http.Response('', 404)),
        baseUrl: () => 'https://api.test',
      );

  final Result<List<GlobalStop>?> result;

  @override
  Future<Result<List<GlobalStop>?>> fetchAllStops() async => result;
}

class _SequenceLearningRepository extends LearningRepository {
  _SequenceLearningRepository(this.results)
    : super(
        client: MockClient((_) async => http.Response('', 404)),
        baseUrl: () => 'https://api.test',
      );

  final List<Result<List<GlobalStop>?>> results;
  int calls = 0;

  @override
  Future<Result<List<GlobalStop>?>> fetchAllStops() async {
    final Result<List<GlobalStop>?> result =
        results[calls < results.length ? calls : results.length - 1];
    calls += 1;
    return result;
  }
}

class _FailingStopArrivalsRepository extends LearningRepository {
  _FailingStopArrivalsRepository()
    : super(
        client: MockClient((_) async => http.Response('', 500)),
        baseUrl: () => 'https://api.test',
      );

  @override
  Future<Result<StopArrivals?>> fetchStopArrivals(String stopId) async {
    return const Err<StopArrivals?>(
      ServerFailure('stop arrivals failed', 'stop_arrivals'),
    );
  }
}

StaticDataRepository _staticRepo({String stopsJson = '[]'}) {
  return StaticDataRepository(
    client: MockClient((_) async => http.Response('', 404)),
    staticBaseUrl: () => 'https://static.test',
    bundleManifestJson: '{}',
    bundleLinesJson: '[]',
    bundleStopsJson: stopsJson,
    prefs: SharedPreferences.getInstance,
    nowMs: () => 0,
  );
}

ProviderContainer _container(
  LearningRepository repo, {
  String staticStopsJson =
      '[{"id":"static-1","lat":-18.72,"lng":-39.85,"name":"Parada"}]',
}) {
  return ProviderContainer(
    overrides: <Override>[
      learningRepositoryProvider.overrideWithValue(repo),
      staticDataRepoProvider.overrideWith(
        (Ref ref) async => _staticRepo(stopsJson: staticStopsJson),
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('uses the learning stops when present', () async {
    final ProviderContainer container = _container(
      _FakeLearningRepository(
        const Ok<List<GlobalStop>?>(<GlobalStop>[
          GlobalStop(id: 'global-1', lat: -18.7, lng: -39.8),
        ]),
      ),
    );
    addTearDown(container.dispose);
    final List<GlobalStop> stops = await container.read(
      allStopsProvider.future,
    );
    expect(stops.single.id, 'global-1');
  });

  test('falls back to static stops on 404', () async {
    final ProviderContainer container = _container(
      _FakeLearningRepository(const Ok<List<GlobalStop>?>(null)),
    );
    addTearDown(container.dispose);
    final List<GlobalStop> stops = await container.read(
      allStopsProvider.future,
    );
    expect(stops.single.id, 'static-1');
    expect(stops.single.name, 'Parada');
    expect(stops.single.lines, isEmpty);
  });

  test('falls back to static stops on failure', () async {
    final ProviderContainer container = _container(
      _FakeLearningRepository(
        const Err<List<GlobalStop>?>(NetworkFailure('offline')),
      ),
    );
    addTearDown(container.dispose);
    final List<GlobalStop> stops = await container.read(
      allStopsProvider.future,
    );
    expect(stops.single.id, 'static-1');
  });

  test('keeps a successful non-empty result cached', () async {
    final _SequenceLearningRepository repo = _SequenceLearningRepository(
      <Result<List<GlobalStop>?>>[
        const Ok<List<GlobalStop>?>(<GlobalStop>[
          GlobalStop(id: 'global-1', lat: -18.7, lng: -39.8),
        ]),
        const Err<List<GlobalStop>?>(NetworkFailure('should not refetch')),
      ],
    );
    final ProviderContainer container = _container(repo);
    addTearDown(container.dispose);
    final List<GlobalStop> first = await container.read(
      allStopsProvider.future,
    );
    final List<GlobalStop> second = await container.read(
      allStopsProvider.future,
    );
    expect(first.single.id, 'global-1');
    expect(second.single.id, 'global-1');
    expect(repo.calls, 1);
  });

  test('does not cache a static fallback after 404', () async {
    final _SequenceLearningRepository repo = _SequenceLearningRepository(
      <Result<List<GlobalStop>?>>[
        const Ok<List<GlobalStop>?>(null),
        const Ok<List<GlobalStop>?>(<GlobalStop>[
          GlobalStop(id: 'global-1', lat: -18.7, lng: -39.8),
        ]),
      ],
    );
    final ProviderContainer container = _container(repo);
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<List<GlobalStop>>> sub = container
        .listen(allStopsProvider, (_, _) {});
    final List<GlobalStop> first = await container.read(
      allStopsProvider.future,
    );
    expect(first.single.id, 'static-1');
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final List<GlobalStop> second = await container.read(
      allStopsProvider.future,
    );
    expect(second.single.id, 'global-1');
    expect(repo.calls, 2);
  });

  test('retries after an empty result with an empty fallback', () async {
    final _SequenceLearningRepository repo = _SequenceLearningRepository(
      <Result<List<GlobalStop>?>>[
        const Err<List<GlobalStop>?>(NetworkFailure('offline')),
        const Ok<List<GlobalStop>?>(<GlobalStop>[
          GlobalStop(id: 'global-1', lat: -18.7, lng: -39.8),
        ]),
      ],
    );
    final ProviderContainer container = _container(repo, staticStopsJson: '[]');
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<List<GlobalStop>>> sub = container
        .listen(allStopsProvider, (_, _) {});
    final List<GlobalStop> first = await container.read(
      allStopsProvider.future,
    );
    expect(first, isEmpty);
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final List<GlobalStop> second = await container.read(
      allStopsProvider.future,
    );
    expect(second.single.id, 'global-1');
    expect(repo.calls, 2);
  });

  test('stop arrivals throws on Err instead of returning null', () async {
    final ProviderContainer container = _container(
      _FailingStopArrivalsRepository(),
    );
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<StopArrivals?>> sub = container
        .listen(
          stopArrivalsProvider('stop-1'),
          (_, _) {},
          fireImmediately: true,
        );
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    final AsyncValue<StopArrivals?> state = container.read(
      stopArrivalsProvider('stop-1'),
    );
    expect(state, isA<AsyncError<StopArrivals?>>());
    expect(
      (state as AsyncError<StopArrivals?>).error,
      isA<StopArrivalsFailure>(),
    );
    await expectLater(
      container.read(stopArrivalsProvider('stop-1').future),
      throwsA(isA<StopArrivalsFailure>()),
    );
  });
}

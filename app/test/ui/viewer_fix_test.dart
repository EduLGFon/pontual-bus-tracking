// Explicit my-stop locating flow: no request on mount, one-shot fix,
// permission and accuracy gates, freshness, and the privacy sheet whose
// request starts only from the "Usar minha localização" tap.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/data/prefs/viewer_location_auto_request.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/features/line/my_stop_location.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A gateway whose servicesOn throws, to verify request never gets stuck
/// in requesting.
class ThrowingServicesGateway implements PermissionGateway {
  @override
  Future<LocationPermissionState> check() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationPermissionState> request() async =>
      LocationPermissionState.granted;

  @override
  Future<bool> servicesOn() async => throw StateError('services boom');

  @override
  Future<bool> preciseAccuracy() async => true;

  @override
  Future<void> openSettings() async {}
}

/// Controllable gateway recording every call.
class RecordingGateway implements PermissionGateway {
  /// Check answers.
  LocationPermissionState checkResult = LocationPermissionState.granted;

  /// Request answers.
  LocationPermissionState requestResult = LocationPermissionState.granted;

  /// Services answer.
  bool servicesOnResult = true;

  /// Precise-accuracy answer.
  bool preciseResult = true;

  /// Calls recorded.
  int checks = 0;

  /// Calls recorded.
  int requests = 0;

  /// Calls recorded.
  int servicesReads = 0;

  /// Calls recorded.
  int preciseReads = 0;

  /// Calls recorded.
  int settingsOpens = 0;

  @override
  Future<LocationPermissionState> check() async {
    checks++;
    return checkResult;
  }

  @override
  Future<LocationPermissionState> request() async {
    requests++;
    return requestResult;
  }

  @override
  Future<bool> servicesOn() async {
    servicesReads++;
    return servicesOnResult;
  }

  @override
  Future<bool> preciseAccuracy() async {
    preciseReads++;
    return preciseResult;
  }

  @override
  Future<void> openSettings() async {
    settingsOpens++;
  }
}

/// Reader counting calls and handing out completer-controlled futures.
class RecordingReader {
  /// Calls recorded.
  int calls = 0;

  List<Completer<Position>> _pending = <Completer<Position>>[];

  /// Completer of the call at [index].
  Completer<Position> pending(int index) => _pending[index];

  /// Answers with a synthetic fix immediately.
  Future<Position> Function() instant({
    LatLng at = const LatLng(-18.72, -39.85),
    double accuracy = 10,
  }) {
    return () async {
      calls++;
      return posOf(at, accuracy);
    };
  }

  /// Next call suspends until its completer is resolved.
  Future<Position> Function() hanging() {
    return () {
      calls++;
      final Completer<Position> completer = Completer<Position>();
      _pending = <Completer<Position>>[..._pending, completer];
      return completer.future;
    };
  }

  /// Fails with a timeout, the shape of a slow fix.
  Future<Position> Function() timingOut() {
    return () async {
      calls++;
      throw TimeoutException('timeLimit');
    };
  }

  /// Fails like a browser denial.
  Future<Position> Function() browserDenied() {
    return () async {
      calls++;
      final StateError error = StateError('browser denied');
      throw error;
    };
  }
}

/// One synthetic position. No real device data anywhere.
Position posOf(LatLng at, double accuracy) {
  return Position(
    latitude: at.latitude,
    longitude: at.longitude,
    timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
    accuracy: accuracy,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 1,
    altitudeAccuracy: 1,
    headingAccuracy: 1,
  );
}

/// Tapper that opens the sheet with the overridden providers.
class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showMyStopLocationSheet(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer containerWithArgs(
    PermissionGateway gateway,
    Future<Position> Function() reader, {
    bool web = false,
  }) {
    return ProviderContainer(
      overrides: <Override>[
        viewerPermissionGatewayProvider.overrideWithValue(gateway),
        viewerPositionReaderProvider.overrideWithValue(reader),
        viewerIsWebProvider.overrideWithValue(web),
      ],
    );
  }

  test('mount never asks: an untouched container stays idle with no calls', () {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.idle);
    expect(container.read(viewerLocationProvider).value, isNull);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(gateway.servicesReads, 0);
    expect(gateway.preciseReads, 0);
    expect(reader.calls, 0);
  });

  test(
    'automatic request on first use asks once and persists the flag',
    () async {
      final RecordingGateway gateway = RecordingGateway()
        ..checkResult = LocationPermissionState.denied
        ..requestResult = LocationPermissionState.granted;
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(),
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).requestAutomatic();

      expect(gateway.checks, 1);
      expect(gateway.requests, 1);
      expect(reader.calls, 1);
      expect(container.read(viewerFixProvider).status, ViewerFixStatus.ready);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(viewerLocationAutoRequestedKey), isTrue);
    },
  );

  test('silent automatic request reuses an existing grant', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).requestAutomatic();

    // Already granted: no OS prompt, but the fix is acquired silently.
    expect(gateway.checks, 1);
    expect(gateway.requests, 0);
    expect(reader.calls, 1);
    expect(container.read(viewerFixProvider).status, ViewerFixStatus.ready);
  });

  test('a denied automatic attempt is not repeated next session', () async {
    final RecordingGateway firstGateway = RecordingGateway()
      ..checkResult = LocationPermissionState.denied
      ..requestResult = LocationPermissionState.denied;
    final RecordingReader firstReader = RecordingReader();
    final ProviderContainer first = containerWithArgs(
      firstGateway,
      firstReader.instant(),
    );
    addTearDown(first.dispose);

    await first.read(viewerFixProvider.notifier).requestAutomatic();

    expect(firstGateway.requests, 1);
    expect(first.read(viewerFixProvider).status, ViewerFixStatus.denied);

    // A new app session reads the persisted flag before asking again.
    final RecordingGateway secondGateway = RecordingGateway()
      ..checkResult = LocationPermissionState.denied;
    final RecordingReader secondReader = RecordingReader();
    final ProviderContainer second = containerWithArgs(
      secondGateway,
      secondReader.instant(),
    );
    addTearDown(second.dispose);

    await second.read(viewerFixProvider.notifier).requestAutomatic();

    // The later attempt may check silently, but never prompts again.
    expect(secondGateway.servicesReads, 1);
    expect(secondGateway.checks, 1);
    expect(secondGateway.requests, 0);
    expect(secondReader.calls, 0);
    expect(second.read(viewerFixProvider).status, ViewerFixStatus.denied);
  });

  test('a later automatic attempt reuses a grant made in settings', () async {
    final RecordingGateway firstGateway = RecordingGateway()
      ..checkResult = LocationPermissionState.denied
      ..requestResult = LocationPermissionState.denied;
    final RecordingReader firstReader = RecordingReader();
    final ProviderContainer first = containerWithArgs(
      firstGateway,
      firstReader.instant(),
    );
    addTearDown(first.dispose);
    await first.read(viewerFixProvider.notifier).requestAutomatic();
    expect(first.read(viewerFixProvider).status, ViewerFixStatus.denied);

    // The rider later grants precise location in system settings.
    final RecordingGateway secondGateway = RecordingGateway();
    final RecordingReader secondReader = RecordingReader();
    final ProviderContainer second = containerWithArgs(
      secondGateway,
      secondReader.instant(),
    );
    addTearDown(second.dispose);

    await second.read(viewerFixProvider.notifier).requestAutomatic();

    expect(secondGateway.checks, 1);
    expect(secondGateway.requests, 0);
    expect(secondReader.calls, 1);
    expect(second.read(viewerFixProvider).status, ViewerFixStatus.ready);
  });

  test(
    'a silent refresh keeps the previous position while in flight',
    () async {
      final RecordingGateway gateway = RecordingGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.hanging(),
      );
      addTearDown(container.dispose);
      final ViewerFixController controller = container.read(
        viewerFixProvider.notifier,
      );

      final Future<void> first = controller.request();
      for (int i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      reader.pending(0).complete(posOf(const LatLng(-18.72, -39.85), 10));
      await first;
      final ViewerFixState prior = container.read(viewerFixProvider);

      final Future<void> refresh = controller.request(
        force: true,
        silent: true,
      );
      for (int i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final ViewerFixState inFlight = container.read(viewerFixProvider);
      expect(inFlight.status, ViewerFixStatus.requesting);
      expect(inFlight.position, prior.position);
      expect(inFlight.accuracyM, prior.accuracyM);
      expect(inFlight.at, prior.at);

      reader.pending(1).complete(posOf(const LatLng(-18.73, -39.86), 12));
      await refresh;

      final ViewerFixState done = container.read(viewerFixProvider);
      expect(done.status, ViewerFixStatus.ready);
      expect(done.accuracyM, 12);
      expect(done.position, const LatLng(-18.73, -39.86));
    },
  );

  test('a failed silent refresh restores the previous fix', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.hanging(),
    );
    addTearDown(container.dispose);
    final ViewerFixController controller = container.read(
      viewerFixProvider.notifier,
    );

    final Future<void> first = controller.request();
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    reader.pending(0).complete(posOf(const LatLng(-18.72, -39.85), 10));
    await first;
    final ViewerFixState prior = container.read(viewerFixProvider);

    final Future<void> refresh = controller.request(force: true, silent: true);
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    reader.pending(1).completeError(TimeoutException('slow fix'));
    await refresh;

    final ViewerFixState after = container.read(viewerFixProvider);
    expect(after.status, ViewerFixStatus.ready);
    expect(after.position, prior.position);
    expect(after.at, prior.at);
  });

  test(
    'granted precise fix becomes ready and feeds the derived provider',
    () async {
      final RecordingGateway gateway = RecordingGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(),
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).request();

      final ViewerFixState fix = container.read(viewerFixProvider);
      expect(fix.status, ViewerFixStatus.ready);
      expect(fix.position, isNotNull);
      expect(fix.accuracyM, 10);
      expect(fix.at, isNotNull);
      expect(await container.read(viewerLocationProvider.future), fix.position);
      expect(gateway.checks, 1);
      expect(gateway.requests, 0);
      expect(reader.calls, 1);
    },
  );

  test('denied request surfaces the denied state without reading', () async {
    final RecordingGateway gateway = RecordingGateway()
      ..checkResult = LocationPermissionState.denied
      ..requestResult = LocationPermissionState.denied;
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.denied);
    expect(gateway.checks, 1);
    expect(gateway.requests, 1);
    expect(gateway.preciseReads, 0);
    expect(reader.calls, 0);
  });

  test('permanently denied surfaces blocked without requesting', () async {
    final RecordingGateway gateway = RecordingGateway()
      ..checkResult = LocationPermissionState.permanentlyDenied;
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.blocked);
    expect(gateway.checks, 1);
    expect(gateway.requests, 0);
    expect(gateway.preciseReads, 0);
    expect(reader.calls, 0);
  });

  test(
    'a gateway that throws leaves the state in error, not requesting',
    () async {
      final ThrowingServicesGateway gateway = ThrowingServicesGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(),
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).request();

      expect(container.read(viewerFixProvider).status, ViewerFixStatus.error);
    },
  );

  test('services off short-circuits before the permission checks', () async {
    final RecordingGateway gateway = RecordingGateway()
      ..servicesOnResult = false;
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(
      container.read(viewerFixProvider).status,
      ViewerFixStatus.servicesOff,
    );
    expect(gateway.servicesReads, 1);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(gateway.preciseReads, 0);
    expect(reader.calls, 0);
  });

  test('approximate-only grant surfaces imprecise without reading', () async {
    final RecordingGateway gateway = RecordingGateway()..preciseResult = false;
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.imprecise);
    expect(gateway.preciseReads, 1);
    expect(reader.calls, 0);
  });

  test('a coarse native fix over 120 m surfaces imprecise', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(accuracy: 150),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.imprecise);
    expect(reader.calls, 1);
    expect(container.read(viewerLocationProvider).value, isNull);
  });

  test(
    'a coarse web fix over 200 m surfaces imprecise and skips the gateway',
    () async {
      final RecordingGateway gateway = RecordingGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(accuracy: 250),
        web: true,
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).request();

      expect(
        container.read(viewerFixProvider).status,
        ViewerFixStatus.imprecise,
      );
      expect(reader.calls, 1);
      expect(gateway.checks, 0);
      expect(gateway.requests, 0);
      expect(gateway.servicesReads, 0);
      expect(gateway.preciseReads, 0);
    },
  );

  test('a web reader failure counts as denied', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.browserDenied(),
      web: true,
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.denied);
  });

  test(
    'a fix outside the served area surfaces outsideArea with no position',
    () async {
      final RecordingGateway gateway = RecordingGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(at: const LatLng(-30.0, -39.85)),
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).request();

      final ViewerFixState fix = container.read(viewerFixProvider);
      expect(fix.status, ViewerFixStatus.outsideArea);
      expect(fix.position, isNull);
    },
  );

  test('a timed out fix surfaces error and never throws', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.timingOut(),
    );
    addTearDown(container.dispose);

    // Must not throw out of request.
    await container.read(viewerFixProvider.notifier).request();

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.error);
    expect(container.read(viewerLocationProvider).value, isNull);
  });

  test('a second call while requesting reuses the in-flight attempt', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.hanging(),
    );
    addTearDown(container.dispose);

    final Future<void> first = container
        .read(viewerFixProvider.notifier)
        .request();
    final Future<void> second = container
        .read(viewerFixProvider.notifier)
        .request();

    // The reentry guard fires synchronously: no second permission ask.
    expect(gateway.requests, 0);
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(reader.calls, 1);
    reader.pending(0).complete(posOf(const LatLng(-18.72, -39.85), 10));
    await Future.wait(<Future<void>>[first, second]);

    expect(container.read(viewerFixProvider).status, ViewerFixStatus.ready);
    expect(reader.calls, 1);
  });

  test(
    'a fresh fix is reused for the next request without a new read',
    () async {
      final RecordingGateway gateway = RecordingGateway();
      final RecordingReader reader = RecordingReader();
      final ProviderContainer container = containerWithArgs(
        gateway,
        reader.instant(),
      );
      addTearDown(container.dispose);

      await container.read(viewerFixProvider.notifier).request();
      await container.read(viewerFixProvider.notifier).request();

      expect(reader.calls, 1);
      expect(container.read(viewerFixProvider).status, ViewerFixStatus.ready);
    },
  );

  test('forced refresh reads a new fix', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(accuracy: 12),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();
    await container.read(viewerFixProvider.notifier).request(force: true);

    expect(reader.calls, 2);
    expect(gateway.checks, 2);
    expect(container.read(viewerFixProvider).accuracyM, 12);
  });

  test('clear drops the fix and returns to idle', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();
    container.read(viewerFixProvider.notifier).clear();

    final ViewerFixState fix = container.read(viewerFixProvider);
    expect(fix.status, ViewerFixStatus.idle);
    expect(fix.position, isNull);
    expect(fix.accuracyM, isNull);
    expect(fix.at, isNull);
  });

  test('adoptTripFix sets ready position, accuracy, and at', () {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    const TripFix fix = TripFix(
      seq: 1,
      lat: -18.72,
      lng: -39.85,
      speedMps: 0,
      heading: null,
      accuracyM: 7,
      batteryPct: 80,
      charging: false,
      acceptedAtMs: 12345,
    );
    container.read(viewerFixProvider.notifier).adoptTripFix(fix);

    final ViewerFixState state = container.read(viewerFixProvider);
    expect(state.status, ViewerFixStatus.ready);
    expect(state.position, const LatLng(-18.72, -39.85));
    expect(state.accuracyM, 7);
    expect(state.at, DateTime.fromMillisecondsSinceEpoch(12345));
  });

  test('an older trip fix does not replace a newer direct fix', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();
    final ViewerFixState prior = container.read(viewerFixProvider);
    expect(prior.status, ViewerFixStatus.ready);

    final TripFix older = TripFix(
      seq: 2,
      lat: -18.73,
      lng: -39.86,
      speedMps: 0,
      heading: null,
      accuracyM: 5,
      batteryPct: 80,
      charging: false,
      acceptedAtMs: prior.at!.millisecondsSinceEpoch - 1000,
    );
    container.read(viewerFixProvider.notifier).adoptTripFix(older);

    final ViewerFixState after = container.read(viewerFixProvider);
    expect(after.position, prior.position);
    expect(after.accuracyM, prior.accuracyM);
    expect(after.at, prior.at);
  });

  test('a coarse trip fix is ignored', () async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await container.read(viewerFixProvider.notifier).request();
    final ViewerFixState prior = container.read(viewerFixProvider);
    expect(prior.status, ViewerFixStatus.ready);

    final TripFix coarse = TripFix(
      seq: 2,
      lat: -18.73,
      lng: -39.86,
      speedMps: 0,
      heading: null,
      accuracyM: 200,
      batteryPct: 80,
      charging: false,
      acceptedAtMs: prior.at!.millisecondsSinceEpoch + 1000,
    );
    container.read(viewerFixProvider.notifier).adoptTripFix(coarse);

    final ViewerFixState after = container.read(viewerFixProvider);
    expect(after.position, prior.position);
    expect(after.accuracyM, prior.accuracyM);
    expect(after.at, prior.at);
  });

  testWidgets('the sheet shows the privacy copy and asks only on tap', (
    WidgetTester tester,
  ) async {
    final RecordingGateway gateway = RecordingGateway();
    final RecordingReader reader = RecordingReader();
    final ProviderContainer container = containerWithArgs(
      gateway,
      reader.instant(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _Launcher()),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Privacy copy visible, nothing asked yet.
    expect(find.text(UiStrings.myStopPrivacyTitle), findsOneWidget);
    expect(find.text(UiStrings.myStopPrivacyBody), findsOneWidget);
    expect(find.text(UiStrings.myStopUseLocation), findsOneWidget);
    expect(find.byType(PontualSheet), findsOneWidget);
    expect(gateway.checks, 0);
    expect(gateway.requests, 0);
    expect(gateway.servicesReads, 0);
    expect(gateway.preciseReads, 0);
    expect(reader.calls, 0);

    await tester.tap(find.text(UiStrings.myStopUseLocation));
    await tester.pumpAndSettle();

    // The request happened and the success closed the sheet.
    expect(gateway.servicesReads, 1);
    expect(gateway.checks, 1);
    expect(reader.calls, 1);
    expect(find.byType(PontualSheet), findsNothing);
    expect(container.read(viewerFixProvider).status, ViewerFixStatus.ready);
  });
}

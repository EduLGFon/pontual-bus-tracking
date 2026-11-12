// Vehicle adapter: maps the live stream onto VehicleVM with display
// ordinals by recency. The data layer keeps its lifecycle and its signals;
// this file only shapes what the UI draws. See docs/ui/UI_SPEC.md 6.2.
// D30: stale-but-moving vehicles with a known pace become predicted
// (extrapolated, dashed) instead of plain stale, always labeled.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/util/lifecycle_ticks.dart';

/// Seconds of moving prediction past the staleness onset. Straight-line
/// dead reckoning leaves the road within seconds on curves, so the horizon
/// stays short: a bus older than `liveFreshS + predictedWhileS` holds at
/// its last fix as a gray stale ghost until the server TTL drops it.
/// Following the line way needs route geometry, which waits for field
/// traces (T17).
const int predictedWhileS = 30;

/// Minimum effective pace in km/h for a prediction. Stopped buses
/// never predict forward.
const double predictedMinKmh = 5;

/// Converts a repository vehicle into its view-model.
VehicleVM vehicleVmOf(
  ClientVehicle vehicle, {
  required String lineKey,
  int? ordinal,
}) {
  final int ageS = vehicle.ageS;
  if (ageS <= liveFreshS) {
    return VehicleVM(
      key: vehicle.id,
      lineKey: lineKey,
      lat: vehicle.lat,
      lng: vehicle.lng,
      headingDeg: vehicle.heading,
      speedKmh: vehicle.kmh,
      ageSeconds: ageS,
      certainty: Certainty.live,
      ordinal: ordinal,
      paceKmh: vehicle.paceKmh,
      members: vehicle.members,
    );
  }
  final double paceKmh = vehicle.paceKmh ?? vehicle.kmh;
  if (ageS <= liveFreshS + predictedWhileS &&
      vehicle.heading != null &&
      paceKmh >= predictedMinKmh) {
    final LatLng predicted = predictPosition(
      vehicle.lat,
      vehicle.lng,
      vehicle.heading,
      paceKmh / 3.6,
      ageS,
    );
    return VehicleVM(
      key: vehicle.id,
      lineKey: lineKey,
      lat: predicted.lat,
      lng: predicted.lng,
      headingDeg: vehicle.heading,
      speedKmh: vehicle.kmh,
      ageSeconds: ageS,
      certainty: Certainty.predicted,
      ordinal: ordinal,
      paceKmh: vehicle.paceKmh,
      members: vehicle.members,
    );
  }
  return VehicleVM(
    key: vehicle.id,
    lineKey: lineKey,
    lat: vehicle.lat,
    lng: vehicle.lng,
    headingDeg: vehicle.heading,
    speedKmh: vehicle.kmh,
    ageSeconds: ageS,
    certainty: Certainty.stale,
    ordinal: ordinal,
    paceKmh: vehicle.paceKmh,
    members: vehicle.members,
  );
}

/// Orders vehicles by age and assigns the display ordinal, so users see
/// "Ônibus 1" for the freshest position and never an internal id.
List<VehicleVM> orderVehicles(List<ClientVehicle> vehicles, String lineKey) {
  final List<ClientVehicle> sorted = List<ClientVehicle>.from(vehicles)
    ..sort((ClientVehicle a, ClientVehicle b) => a.ageS.compareTo(b.ageS));
  return <VehicleVM>[
    for (int i = 0; i < sorted.length; i++)
      vehicleVmOf(sorted[i], lineKey: lineKey, ordinal: i + 1),
  ];
}

/// Slow rebuild signal for the live list: 5 s is enough for the "há N s"
/// labels and the staleness flip, exactly like the previous map tab. No
/// stream is opened by this provider, the repository owns the socket.
///
/// Auto-disposed and paused while the app is not resumed: the tick stops
/// when no line screen watches it and never rebuilds an invisible screen.
final StreamProvider<int> vehicleTickProvider = StreamProvider.autoDispose<int>(
  (Ref ref) {
    // Data saver stretches the live tick from 5 s to 30 s so a rider on
    // a metered connection does not pay for per-vehicle age labels every
    // few seconds. The repository still owns the socket; only the UI
    // age labels slow down.
    final bool dataSaver = ref.watch(settingsProvider).dataSaver;
    return lifecycleTicks(
      dataSaver ? const Duration(seconds: 30) : const Duration(seconds: 5),
    );
  },
);

/// Throttled change stream for one line: at most one rebuild per second
/// in normal mode, so WebSocket frames become visible without waiting for
/// the 5 s age tick and without rebuild storms.
final vehicleChangeProvider = StreamProvider.autoDispose.family<int, int>((
  Ref ref,
  int lineId,
) {
  final VehicleRepository repo = ref.watch(vehicleRepoProvider(lineId));
  final StreamController<int> controller = StreamController<int>.broadcast();
  Timer? timer;
  bool pending = false;
  int count = 0;

  void emit() {
    count++;
    controller.add(count);
    timer = Timer(const Duration(seconds: 1), () {
      timer = null;
      if (pending) {
        pending = false;
        emit();
      }
    });
  }

  final StreamSubscription<void> sub = repo.changes.listen((_) {
    if (timer == null) {
      emit();
    } else {
      pending = true;
    }
  });
  ref.onDispose(() {
    sub.cancel();
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Vehicles for one line id, re-sorted on ticks and on throttled frame
/// changes. The provider family is plain, so a line consumed twice shares
/// one instance.
///
/// Auto-disposed with the screen: leaving the last watching line stops
/// the tick above and drops the sorted copy.
final vehiclesVmProvider = Provider.autoDispose.family<List<VehicleVM>, int>((
  Ref ref,
  int lineId,
) {
  final bool dataSaver = ref.watch(settingsProvider).dataSaver;
  ref.watch(vehicleTickProvider);
  if (!dataSaver) {
    ref.watch(vehicleChangeProvider(lineId));
  }
  final VehicleRepository repo = ref.watch(vehicleRepoProvider(lineId));
  return orderVehicles(repo.vehicles, lineId.toString());
});

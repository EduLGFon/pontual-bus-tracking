// Vehicle adapter: maps the live stream onto VehicleVM with display
// ordinals by recency. The data layer keeps its lifecycle and its signals;
// this file only shapes what the UI draws. See docs/ui/UI_SPEC.md 6.2.
// D30: stale-but-moving vehicles with a known pace become predicted
// (extrapolated, dashed) instead of plain stale, always labeled.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Last age in seconds that still renders a moving prediction. Straight-line
/// dead reckoning leaves the road within seconds on curves, so the horizon
/// stays short: beyond it the bus holds at its last fix as a gray stale
/// ghost until the server TTL drops it. Following the line way needs route
/// geometry, which waits for field traces (T17).
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
  if (ageS <= predictedWhileS &&
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
/// Auto-disposed: the tick stops when no line screen watches it, instead
/// of waking the isolate every 5 s for the whole app lifetime.
final StreamProvider<int> vehicleTickProvider = StreamProvider.autoDispose<int>(
  (Ref ref) {
    return Stream<int>.periodic(const Duration(seconds: 5), (int i) => i);
  },
);

/// Vehicles for one line id, re-sorted on every tick. The provider family
/// is plain, so a line consumed twice shares one instance.
///
/// Auto-disposed with the screen: leaving the last watching line stops
/// the tick above and drops the sorted copy.
final vehiclesVmProvider = Provider.autoDispose.family<List<VehicleVM>, int>((
  Ref ref,
  int lineId,
) {
  ref.watch(vehicleTickProvider);
  final VehicleRepository repo = ref.watch(vehicleRepoProvider(lineId));
  return orderVehicles(repo.vehicles, lineId.toString());
});

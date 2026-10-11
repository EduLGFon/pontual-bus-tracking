// Vehicle adapter: maps the live stream onto VehicleVM with display
// ordinals by recency. The data layer keeps its lifecycle and its signals;
// this file only shapes what the UI draws. See docs/ui/UI_SPEC.md 6.2.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

/// Converts a repository vehicle into its view-model.
VehicleVM vehicleVmOf(
  ClientVehicle vehicle, {
  required String lineKey,
  int? ordinal,
}) {
  return VehicleVM(
    key: vehicle.id,
    lineKey: lineKey,
    lat: vehicle.lat,
    lng: vehicle.lng,
    headingDeg: vehicle.heading,
    speedKmh: vehicle.kmh,
    ageSeconds: vehicle.ageS,
    certainty: certaintyForAge(vehicle.ageS),
    ordinal: ordinal,
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
final StreamProvider<int> vehicleTickProvider = StreamProvider<int>((Ref ref) {
  return Stream<int>.periodic(const Duration(seconds: 5), (int i) => i);
});

/// Vehicles for one line id, re-sorted on every tick. The provider family
/// is plain, so a line consumed twice shares one instance.
final vehiclesVmProvider = Provider.family<List<VehicleVM>, int>((
  Ref ref,
  int lineId,
) {
  ref.watch(vehicleTickProvider);
  final VehicleRepository repo = ref.watch(vehicleRepoProvider(lineId));
  return orderVehicles(repo.vehicles, lineId.toString());
});

// D30 pace and prediction tests. Pure logic: 8-field rows parse on new
// servers and 7-field rows still parse on old ones; stale-but-moving
// vehicles become labeled predictions, stopped or very old ones stay stale.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/models/certainty.dart';

void main() {
  test('7-field rows parse with null pace', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 29.0, 1, 4],
    );
    expect(v.paceKmh, isNull);
    expect(v.kmh, 29.0);
  });

  test('8-field rows parse the pace', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 29.0, 1, 4, 25.5],
    );
    expect(v.paceKmh, 25.5);
  });

  test('fresh vehicles stay live at the real fix', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 29.0, 1, 4, 25.5],
    );
    final vm = vehicleVmOf(v, lineKey: '60');
    expect(vm.certainty, Certainty.live);
    expect(vm.lat, -18.72);
    expect(vm.paceKmh, 25.5);
  });

  test('stale moving vehicles predict forward and are labeled', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 29.0, 1, 90, 28.8],
    );
    final vm = vehicleVmOf(v, lineKey: '60');
    expect(vm.certainty, Certainty.predicted);
    // Eastward heading moves longitude forward, latitude stays.
    expect(vm.lng > -39.85, isTrue);
    expect((vm.lat - -18.72).abs() < 0.001, isTrue);
  });

  test('stopped buses never predict', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 0.0, 1, 90, 0.0],
    );
    final vm = vehicleVmOf(v, lineKey: '60');
    expect(vm.certainty, Certainty.stale);
    expect(vm.lat, -18.72);
  });

  test('very old vehicles go stale, not predicted', () {
    final ClientVehicle v = ClientVehicle.fromRow(
      <dynamic>[3, -18.72, -39.85, 90, 29.0, 1, 400, 28.8],
    );
    final vm = vehicleVmOf(v, lineKey: '60');
    expect(vm.certainty, Certainty.stale);
  });

  test('predictPosition mirrors the server dead reckoning', () {
    final LatLng p = predictPosition(-18.72, -39.85, 90, 8, 60);
    expect((p.lat - -18.72).abs() < 0.0005, isTrue);
    expect(p.lng > -39.85, isTrue);
    final LatLng still = predictPosition(-18.72, -39.85, null, 8, 60);
    expect(still.lat, -18.72);
    expect(still.lng, -39.85);
  });
}

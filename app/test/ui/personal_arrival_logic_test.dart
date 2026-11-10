// Pure logic tests for the personal arrival view-model: nearest stop,
// approach filter, ETA mapping, statuses and lead selection.
// No widgets, no providers, no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/core/geo/geo.dart';
import 'package:pontual/domain/learning/eta_estimate.dart';
import 'package:pontual/domain/learning/learned_stop.dart';
import 'package:pontual/ui/adapters/personal_arrival.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

const LatLng rider = LatLng(0, 0);

// The chosen stop is about 200 m north of the rider.
const LearnedStop stopMain = LearnedStop(
  id: 'stop-a',
  ordinal: 0,
  lat: 0.00179864,
  lng: 0,
  radiusM: 30,
  passes: 8,
);

// About 100 m north of the rider.
const LearnedStop stop100 = LearnedStop(
  id: '100',
  ordinal: 1,
  lat: 0.00089932,
  lng: 0,
  radiusM: 30,
  passes: 3,
);

// About 42.6 m north of the rider, rounds to 43 m.
const LearnedStop stop42m6 = LearnedStop(
  id: '43',
  ordinal: 2,
  lat: 0.00038311,
  lng: 0,
  radiusM: 30,
  passes: 1,
);

// About 300 m north of the rider, just inside the radius.
const LearnedStop stop300 = LearnedStop(
  id: '300',
  ordinal: 3,
  lat: 0.00269796,
  lng: 0,
  radiusM: 30,
  passes: 2,
);

// About 301 m north of the rider, beyond the radius.
const LearnedStop stop301 = LearnedStop(
  id: '301',
  ordinal: 4,
  lat: 0.00270692,
  lng: 0,
  radiusM: 30,
  passes: 2,
);

// About 500 m north of the rider, far from every candidate stop.
const LearnedStop stop500 = LearnedStop(
  id: '500',
  ordinal: 5,
  lat: 0.00449664,
  lng: 0,
  radiusM: 30,
  passes: 2,
);

// Vehicles placed south of stopMain. Key is the internal id, never shown.
const VehicleVM busFar = VehicleVM(
  key: 1,
  lineKey: '66',
  lat: -0.002698,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

const VehicleVM busMid = VehicleVM(
  key: 2,
  lineKey: '66',
  lat: -0.00179865,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

const VehicleVM busNear = VehicleVM(
  key: 3,
  lineKey: '66',
  lat: 0.00089931,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

const VehicleVM busAtStop = VehicleVM(
  key: 4,
  lineKey: '66',
  lat: 0,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

const VehicleVM busAway = VehicleVM(
  key: 5,
  lineKey: '66',
  lat: -0.00179865,
  lng: 0,
  headingDeg: 180,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

const VehicleVM busStale = VehicleVM(
  key: 6,
  lineKey: '66',
  lat: -0.00179865,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 90,
  certainty: Certainty.stale,
);

// Vehicle south of the stop, heading north: points at the stop.
const VehicleVM busToward = VehicleVM(
  key: 7,
  lineKey: '66',
  lat: -0.00179865,
  lng: 0,
  headingDeg: 0,
  speedKmh: 20,
  ageSeconds: 0,
  certainty: Certainty.live,
);

final DateTime referenceNow = DateTime.utc(2026, 11, 10, 12);

PersonalArrivalVM build({
  LatLng? viewer = rider,
  DateTime? fixAt,
  bool stopsLoading = false,
  List<LearnedStop> stops = const <LearnedStop>[stopMain],
  List<VehicleVM> vehicles = const <VehicleVM>[],
  EtaResult? eta,
  bool etaLoading = false,
  bool etaFailed = false,
}) {
  return buildPersonalArrival(
    viewer: viewer,
    now: referenceNow,
    fixAt: fixAt,
    stopsLoading: stopsLoading,
    stops: stops,
    vehicles: vehicles,
    eta: eta,
    etaLoading: etaLoading,
    etaFailed: etaFailed,
  );
}

void main() {
  group('nearestStopOf', () {
    test('empty list returns null', () {
      expect(nearestStopOf(rider, const <LearnedStop>[]), isNull);
    });

    test('single stop inside the radius is returned', () {
      expect(nearestStopOf(rider, const <LearnedStop>[stopMain]), stopMain);
    });

    test('closest of two stops wins', () {
      expect(
        nearestStopOf(rider, const <LearnedStop>[stopMain, stop100]),
        stop100,
      );
    });

    test('a stop at the 300 m boundary is kept', () {
      expect(nearestStopOf(rider, const <LearnedStop>[stop300]), stop300);
    });

    test('a stop beyond 300 m is rejected', () {
      expect(nearestStopOf(rider, const <LearnedStop>[stop301]), isNull);
    });
  });

  group('nearestStopDistanceM', () {
    test('rounds the distance to whole meters', () {
      expect(nearestStopDistanceM(rider, const <LearnedStop>[stop42m6]), 43);
    });

    test('returns null beyond the radius', () {
      expect(nearestStopDistanceM(rider, const <LearnedStop>[stop301]), isNull);
    });
  });

  group('isApproaching', () {
    test('heading toward the stop is approaching', () {
      expect(isApproaching(busToward, stopMain), isTrue);
    });

    test('heading away from the stop is not approaching', () {
      expect(isApproaching(busAway, stopMain), isFalse);
    });

    test('unknown heading counts as approaching', () {
      const VehicleVM bus = VehicleVM(
        key: 8,
        lineKey: '66',
        lat: -0.00179865,
        lng: 0,
        speedKmh: 20,
        ageSeconds: 0,
        certainty: Certainty.live,
      );
      expect(isApproaching(bus, stopMain), isTrue);
    });

    test('a stopped vehicle counts as approaching even when facing away', () {
      const VehicleVM bus = VehicleVM(
        key: 9,
        lineKey: '66',
        lat: -0.00179865,
        lng: 0,
        headingDeg: 180,
        speedKmh: 0,
        ageSeconds: 0,
        certainty: Certainty.live,
      );
      expect(isApproaching(bus, stopMain), isTrue);
    });
  });

  group('buildPersonalArrival statuses', () {
    test('no viewer asks for location', () {
      final PersonalArrivalVM vm = build(viewer: null);
      expect(vm.status, PersonalArrivalStatus.needsLocation);
      expect(vm.staleFix, isFalse);
    });

    test('a stale fix asks for location and drops the stop', () {
      final PersonalArrivalVM vm = build(
        fixAt: referenceNow.subtract(const Duration(seconds: 301)),
      );
      expect(vm.status, PersonalArrivalStatus.needsLocation);
      expect(vm.staleFix, isTrue);
      expect(vm.stopId, isNull);
      expect(vm.stopLat, isNull);
      expect(vm.stopLng, isNull);
      expect(vm.stopDistanceM, isNull);
    });

    test('a fix exactly 5 minutes old is still fresh', () {
      final PersonalArrivalVM vm = build(
        fixAt: referenceNow.subtract(const Duration(seconds: 300)),
      );
      expect(vm.status, PersonalArrivalStatus.noLive);
      expect(vm.staleFix, isFalse);
    });

    test('loading stops reports loadingStops', () {
      expect(
        build(stopsLoading: true).status,
        PersonalArrivalStatus.loadingStops,
      );
    });

    test('an empty stop list reports noStops', () {
      expect(
        build(stops: const <LearnedStop>[]).status,
        PersonalArrivalStatus.noStops,
      );
    });

    test('no stop within the radius reports noStopNear', () {
      expect(
        build(stops: const <LearnedStop>[stop500]).status,
        PersonalArrivalStatus.noStopNear,
      );
    });

    test('no live vehicle reports noLive with the stop fields filled', () {
      final PersonalArrivalVM vm = build();
      expect(vm.status, PersonalArrivalStatus.noLive);
      expect(vm.stopId, 'stop-a');
      expect(vm.stopLat, stopMain.lat);
      expect(vm.stopLng, stopMain.lng);
      expect(vm.stopDistanceM, 200);
      expect(vm.byVehicle, isEmpty);
      expect(vm.lead, isNull);
      expect(vm.isReady, isFalse);
    });

    test('a UUID-shaped learned stop id is preserved exactly', () {
      const LearnedStop uuidStop = LearnedStop(
        id: '3f2a6c1e-9b4d-4a7e-8c55-1d2e3f4a5b6c',
        ordinal: 0,
        lat: 0.00179864,
        lng: 0,
        radiusM: 30,
        passes: 4,
      );
      final PersonalArrivalVM vm = build(stops: const <LearnedStop>[uuidStop]);
      expect(vm.status, PersonalArrivalStatus.noLive);
      expect(vm.stopId, '3f2a6c1e-9b4d-4a7e-8c55-1d2e3f4a5b6c');
    });

    test('a live vehicle with no ETA response reports etaLoading', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        etaLoading: true,
      );
      expect(vm.status, PersonalArrivalStatus.etaLoading);
      expect(vm.stopId, 'stop-a');
    });

    test('a failed ETA request reports etaError', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        etaFailed: true,
      );
      expect(vm.status, PersonalArrivalStatus.etaError);
    });

    test('a missing ETA response reports etaError', () {
      expect(
        build(vehicles: const <VehicleVM>[busMid]).status,
        PersonalArrivalStatus.etaError,
      );
    });

    test('a non-live vehicle is ignored and reports noLive', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busStale],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 6,
              etaS: 300,
              confidence: 'high',
              sampleCount: 4,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.noLive);
      expect(vm.byVehicle, isEmpty);
    });

    test('a live vehicle missing from the ETA response is ignored', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        eta: const EtaResult(stopId: '42', nowS: 100, items: <EtaItem>[]),
      );
      expect(vm.status, PersonalArrivalStatus.noApproaching);
      expect(vm.byVehicle, isEmpty);
      expect(vm.lead, isNull);
    });
  });

  group('buildPersonalArrival ETA mapping', () {
    test('an ETA over 90 minutes is ignored', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 1,
              etaS: 5401,
              confidence: 'high',
              sampleCount: 4,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.noApproaching);
      expect(vm.byVehicle, isEmpty);
    });

    test('an ETA of exactly 90 minutes is kept', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 1,
              etaS: 5400,
              confidence: 'medium',
              sampleCount: 4,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.ready);
      expect(vm.lead?.minutes, 90);
    });

    test('a zero ETA far from the stop stays hidden', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(vehicleId: 1, etaS: 0, confidence: 'low', sampleCount: 1),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.noApproaching);
      expect(vm.byVehicle, isEmpty);
    });

    test('a zero ETA near the stop is arriving', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busAtStop],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(vehicleId: 4, etaS: 0, confidence: 'high', sampleCount: 2),
          ],
        ),
      );
      final PersonalEtaVM row = vm.byVehicle[4]!;
      expect(vm.status, PersonalArrivalStatus.ready);
      expect(row.arriving, isTrue);
      expect(row.label, UiStrings.myStopArrivingUntilYou);
      expect(row.semantic, UiStrings.myStopA11yArriving(200));
      expect(vm.lead, row);
    });

    test('close distance means arriving even with a long ETA', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busNear],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 3,
              etaS: 600,
              confidence: 'high',
              sampleCount: 9,
            ),
          ],
        ),
      );
      final PersonalEtaVM row = vm.byVehicle[3]!;
      expect(row.arriving, isTrue);
      expect(row.label, UiStrings.myStopArrivingUntilYou);
    });

    test('an ETA of 60 seconds means arriving even when far', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(vehicleId: 1, etaS: 60, confidence: 'high', sampleCount: 5),
          ],
        ),
      );
      expect(vm.byVehicle[1]!.arriving, isTrue);
      expect(vm.byVehicle[1]!.semantic, UiStrings.myStopA11yArriving(500));
    });

    test('a bus heading away and far is marked as passed', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busAway],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 5,
              etaS: 120,
              confidence: 'high',
              sampleCount: 3,
            ),
          ],
        ),
      );
      final PersonalEtaVM row = vm.byVehicle[5]!;
      expect(row.passed, isTrue);
      expect(row.approaching, isFalse);
      expect(row.label, UiStrings.myStopPassedUntilYou);
      expect(row.semantic, UiStrings.myStopPassedUntilYou);
      expect(vm.status, PersonalArrivalStatus.noApproaching);
      expect(vm.lead, isNull);
      expect(vm.byVehicle, contains(5));
    });

    test('minutes round with a minimum of one', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(vehicleId: 1, etaS: 61, confidence: 'high', sampleCount: 5),
          ],
        ),
      );
      final PersonalEtaVM row = vm.byVehicle[1]!;
      expect(row.minutes, 1);
      expect(row.label, UiStrings.myStopEtaUntilYou(1));
      expect(row.semantic, UiStrings.myStopA11y(1, 500));
    });

    test('the two bus lead is the smallest ETA', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar, busMid],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 1,
              etaS: 600,
              confidence: 'high',
              sampleCount: 6,
            ),
            EtaItem(
              vehicleId: 2,
              etaS: 300,
              confidence: 'high',
              sampleCount: 6,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.ready);
      expect(vm.lead?.vehicleKey, 2);
      expect(vm.lead?.minutes, 5);
      expect(vm.byVehicle.length, 2);
    });

    test('an ETA tie goes to the bus closer to the stop', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar, busMid],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 1,
              etaS: 300,
              confidence: 'high',
              sampleCount: 6,
            ),
            EtaItem(
              vehicleId: 2,
              etaS: 300,
              confidence: 'high',
              sampleCount: 6,
            ),
          ],
        ),
      );
      expect(vm.lead?.vehicleKey, 2);
    });

    test('byVehicle is keyed by vehicle key', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar, busMid],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(vehicleId: 1, etaS: 600, confidence: 'low', sampleCount: 2),
            EtaItem(vehicleId: 2, etaS: 300, confidence: 'low', sampleCount: 2),
          ],
        ),
      );
      expect(vm.byVehicle.keys, containsAll(<int>[1, 2]));
      expect(vm.byVehicle[1]?.vehicleKey, 1);
      expect(vm.byVehicle[2]?.vehicleKey, 2);
    });

    test('server confidence maps to 0, 1 or 2', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busFar, busMid, busNear, busAtStop],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 1,
              etaS: 600,
              confidence: 'high',
              sampleCount: 6,
            ),
            EtaItem(
              vehicleId: 2,
              etaS: 600,
              confidence: 'medium',
              sampleCount: 6,
            ),
            EtaItem(vehicleId: 3, etaS: 600, confidence: 'low', sampleCount: 6),
            EtaItem(
              vehicleId: 4,
              etaS: 600,
              confidence: 'unexpected',
              sampleCount: 6,
            ),
          ],
        ),
      );
      expect(vm.byVehicle[1]?.confidence, 2);
      expect(vm.byVehicle[2]?.confidence, 1);
      expect(vm.byVehicle[3]?.confidence, 0);
      expect(vm.byVehicle[4]?.confidence, 0);
    });

    test('the sample count is preserved', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 2,
              etaS: 300,
              confidence: 'medium',
              sampleCount: 7,
            ),
          ],
        ),
      );
      expect(vm.byVehicle[2]?.sampleCount, 7);
    });

    test('a cached ETA stays visible while a refresh is loading', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        etaLoading: true,
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 2,
              etaS: 300,
              confidence: 'high',
              sampleCount: 5,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.ready);
      expect(vm.lead?.vehicleKey, 2);
    });

    test('a failed refresh wins over a cached ETA', () {
      final PersonalArrivalVM vm = build(
        vehicles: const <VehicleVM>[busMid],
        etaFailed: true,
        eta: const EtaResult(
          stopId: '42',
          nowS: 100,
          items: <EtaItem>[
            EtaItem(
              vehicleId: 2,
              etaS: 300,
              confidence: 'high',
              sampleCount: 5,
            ),
          ],
        ),
      );
      expect(vm.status, PersonalArrivalStatus.etaError);
    });
  });
}

// D30 live-logic tests. Pure: hero choice, alert matching, reliability
// aggregates and scheduled headways. No prefs, no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/adapters/alerts_store.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/models/alert_rule.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';

final DateTime now = DateTime.utc(2026, 10, 14, 14, 23);

VehicleVM vehicle(int ageS, Certainty certainty) {
  return VehicleVM(
    key: ageS,
    lineKey: '60',
    lat: -18.72,
    lng: -39.85,
    headingDeg: 90,
    speedKmh: 29,
    ageSeconds: ageS,
    certainty: certainty,
  );
}

void main() {
  test('live hero prefers the freshest live vehicle', () {
    final ArrivalVM? hero = liveHeroOf(
      '60',
      <VehicleVM>[vehicle(30, Certainty.live), vehicle(4, Certainty.live)],
      now,
    );
    expect(hero, isNotNull);
    expect(hero!.certainty, Certainty.live);
    expect(hero.at, now);
  });

  test('predicted hero applies when nothing is live', () {
    final ArrivalVM? hero = liveHeroOf(
      '60',
      <VehicleVM>[vehicle(90, Certainty.predicted)],
      now,
    );
    expect(hero, isNotNull);
    expect(hero!.certainty, Certainty.predicted);
  });

  test('no hero without live or predicted vehicles', () {
    expect(
      liveHeroOf('60', <VehicleVM>[vehicle(400, Certainty.stale)], now),
      isNull,
    );
    expect(liveHeroOf('60', const <VehicleVM>[], now), isNull);
  });

  test('alerts fire only for active rules on live lines', () {
    final List<AlertRuleVM> rules = <AlertRuleVM>[
      const AlertRuleVM(lineKey: '60', minutesBefore: 5),
      const AlertRuleVM(lineKey: '61', minutesBefore: 5, active: false),
      const AlertRuleVM(lineKey: '62', minutesBefore: 5),
    ];
    final List<AlertRuleVM> fired = triggeredAlerts(
      rules: rules,
      liveLineKeys: <String>{'60', '61'},
      now: now,
    );
    expect(fired.map((AlertRuleVM r) => r.lineKey), <String>['60']);
  });

  test('alert weekday filter respects repeat days', () {
    // 2026-10-14 is a Wednesday (weekday 3).
    const AlertRuleVM rule = AlertRuleVM(
      lineKey: '60',
      minutesBefore: 5,
      days: <int>[1],
    );
    expect(
      triggeredAlerts(
        rules: const <AlertRuleVM>[rule],
        liveLineKeys: <String>{'60'},
        now: now,
      ),
      isEmpty,
    );
  });

  test('reliability hides below two sightings', () {
    expect(
      reliabilityOf(
        passages: const <int>[100],
        headwayMin: null,
        scheduledHeadwayMin: 10,
      ),
      isNull,
    );
  });

  test('reliability delay is actual minus scheduled, floored', () {
    final ReliabilityVM? r = reliabilityOf(
      passages: const <int>[0, 900, 2100],
      headwayMin: 17.5,
      scheduledHeadwayMin: 15,
    );
    expect(r, isNotNull);
    expect(r!.typicalDelayMin, 3);
    expect(r.sampleSize, 3);
    expect(r.bars.length, 2);
    const ReliabilityVM? early = null;
    expect(
      reliabilityOf(
        passages: const <int>[0, 600],
        headwayMin: 10,
        scheduledHeadwayMin: 15,
      )?.typicalDelayMin,
      0,
    );
    expect(early, isNull);
  });

  test('scheduled headway is the median timetable gap', () {
    expect(
      scheduledHeadwayOf(const <String>['05:30', '06:00', '06:30']),
      30,
    );
    expect(scheduledHeadwayOf(const <String>['05:30']), isNull);
  });
}

// Unit tests for the flagged-off future models and seams: alert rules,
// reliability aggregates, the alerts store, and the composite arrivals
// merge. Flags off means zero visual change; these are data only.
// See docs/ui/UI_SPEC.md 13 and 16 (U25).
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/ui/adapters/alerts_store.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/models/alert_rule.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/features.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AlertRuleVM round-trips and tolerates unknown JSON', () {
    const AlertRuleVM rule = AlertRuleVM(
      lineKey: '60-litoraneo-aviacao',
      minutesBefore: 5,
      days: <int>[1, 2, 3, 4, 5],
    );
    final AlertRuleVM back = AlertRuleVM.fromJson(rule.toJson());
    expect(back.lineKey, '60-litoraneo-aviacao');
    expect(back.minutesBefore, 5);
    expect(back.days, <int>[1, 2, 3, 4, 5]);
    expect(back.active, isTrue);
    final AlertRuleVM odd = AlertRuleVM.fromJson(<String, dynamic>{
      'line_key': 7,
      'minutes_before': 'x',
    });
    expect(odd.lineKey, isEmpty);
    expect(odd.minutesBefore, 5);
  });

  test('ReliabilityVM clamps bars and tolerates wrong types', () {
    final ReliabilityVM vm = ReliabilityVM.fromJson(<String, dynamic>{
      'typical_delay_min': 4,
      'sample_size': 120,
      'bars': <dynamic>[0.2, 1.5, -0.5, 'x'],
    });
    expect(vm.typicalDelayMin, 4);
    expect(vm.sampleSize, 120);
    expect(vm.bars, <double>[0.2, 1.0, 0.0]);
    expect(
      UiStrings.typicalDelayOf(4),
      'Costuma atrasar cerca de 4 min neste horário',
    );
  });

  test('AlertsStore writes, reads and clears', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const AlertsStore store = AlertsStore();
    expect(await store.read(), isEmpty);
    await store.write(const <AlertRuleVM>[
      AlertRuleVM(lineKey: '60-litoraneo-aviacao', minutesBefore: 5),
    ]);
    expect((await store.read()).length, 1);
    await store.clear();
    expect(await store.read(), isEmpty);
  });

  test('CompositeArrivalsSource prefers live over scheduled', () {
    final DateTime now = DateTime.utc(2026, 10, 14, 14, 20);
    final ArrivalVM scheduled = ArrivalVM(
      lineKey: 'x',
      at: DateTime.utc(2026, 10, 14, 14, 35),
      certainty: Certainty.scheduled,
      asOf: now,
    );
    final ArrivalVM live = ArrivalVM(
      lineKey: 'x',
      at: DateTime.utc(2026, 10, 14, 14, 24),
      certainty: Certainty.live,
      asOf: now,
    );
    final List<ArrivalVM> merged = CompositeArrivalsSource.mergeByRank(
      <ArrivalVM>[scheduled, live],
    );
    expect(merged.length, 1);
    expect(merged.first.certainty, Certainty.live);
  });

  test('Features parses localKudos and ignores unknown keys', () {
    // D30: momentum flags default on; unknown or wrong-typed values
    // still fall back to the default instead of breaking.
    const Features base = Features();
    expect(base.localKudos, isTrue);
    expect(base.eta, isTrue);
    final Features on = Features.fromJson(<String, dynamic>{
      'local_kudos': true,
      'other': true,
      'eta': 'x',
    });
    expect(on.localKudos, isTrue);
    expect(on.eta, isTrue);
    final Features off = Features.fromJson(<String, dynamic>{
      'eta': false,
    });
    expect(off.eta, isFalse);
  });

  test('confidence and pace copy matches UI_SPEC 14', () {
    expect(UiStrings.confidenceLabel(0), UiStrings.confLow);
    expect(UiStrings.confidenceLabel(1), UiStrings.confMid);
    expect(UiStrings.confidenceLabel(9), UiStrings.confHigh);
    expect(UiStrings.paceFaster, contains('mais rápido'));
    expect(UiStrings.alertTitle, 'Avisar quando faltar');
    expect(UiStrings.tabHistory, 'Histórico');
  });
}

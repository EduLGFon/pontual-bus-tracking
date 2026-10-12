// Read-only sharing signals on TripController: the fix path records
// accuracy and battery, the supervisor clock surfaces the last success,
// and the memoized selector returns identical results for identical
// inputs without changing behavior.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/trip/sharing_health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trip_rig.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('started trip exposes fix signals and resolves live', () async {
    final Rig r = rig(happy());
    await start(r);
    r.positions.add(pos(8));
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(r.controller.lastAccuracyM, 10);
    expect(r.controller.lastBatteryPct, 80);
    expect(r.controller.lastCharging, isFalse);
    expect(r.controller.permissionRevoked, isFalse);
    expect(r.controller.servicesOn, isTrue);
    expect(r.controller.lastSuccessMs, isNotNull);
    final SharingHealth h = r.controller.sharingHealth(101000);
    expect(h.overall, SharingOverall.live);
    expect(h.issue, SharingIssue.none);
    final SharingHealth again = r.controller.sharingHealth(101000);
    expect(identical(h, again), isTrue);
    addTearDown(() async {
      await r.controller.endTrip();
      r.controller.dispose();
      await r.positions.close();
    });
  });

  test('fresh controller reports no fix data', () {
    final Rig r = rig(happy());
    expect(r.controller.lastAccuracyM, isNull);
    expect(r.controller.lastBatteryPct, isNull);
    expect(r.controller.lastSuccessMs, isNull);
    expect(r.controller.servicesOn, isTrue);
    r.controller.dispose();
  });
}

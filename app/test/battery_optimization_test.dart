// Battery exemption helper tests: best-effort, never throws off-device.
// The real permission dialog only exists on Android hardware; here the
// platform channel has no native side, so both calls must finish as false.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/platform/android/battery_optimization.dart';

void main() {
  test('exemption helpers never throw off-device', () async {
    final bool ignoring = await isIgnoringBatteryOptimizations().timeout(
      const Duration(seconds: 10),
    );
    expect(ignoring, isFalse);
    final bool granted = await requestIgnoreBatteryOptimizations().timeout(
      const Duration(seconds: 10),
    );
    expect(granted, isFalse);
  });
}

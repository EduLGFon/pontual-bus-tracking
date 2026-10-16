// Best-effort battery exemption for the trip foreground service.
// Samsung and Xiaomi skins kill background GPS even with a location-type
// foreground service; the system exemption dialog keeps sharing alive
// with the screen off. Android only, user-tapped only, never blocks
// sharing, never throws. Needs the REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
// manifest permission (owner order D61). See PLAN.md 8.6.
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pontual/core/logging/log.dart';

/// Requests the exemption, defaulting to the production permission call.
/// Injectable so widget tests never touch a platform channel (an unmocked
/// channel never resolves under testWidgets and would hang the test).
typedef RequestExemption = Future<bool> Function();

/// True when the app already ignores battery optimizations.
/// False on web, non-Android, or any failure. Never throws.
Future<bool> isIgnoringBatteryOptimizations() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  } catch (_) {
    return false;
  }
}

/// Fires the system exemption dialog. Call only from a user tap while a
/// trip is offline: an unprompted system dialog is the fastest way to
/// lose trust. Returns true when granted. Never throws.
Future<bool> requestIgnoreBatteryOptimizations() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    if (await Permission.ignoreBatteryOptimizations.isGranted) {
      return true;
    }
    final PermissionStatus after =
        await Permission.ignoreBatteryOptimizations.request();
    if (!after.isGranted) {
      Log.w('battery exemption denied', 'trip continues');
    }
    return after.isGranted;
  } catch (_) {
    Log.w('battery exemption request failed', 'trip continues');
    return false;
  }
}

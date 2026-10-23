// Best-effort notification permission for the trip foreground service.
// Android 13+ hides the sharing notification while POST_NOTIFICATIONS is
// denied, but the trip itself keeps running. This asks once per share
// attempt, never blocks sharing, and never throws. Location permission
// stays owned by the PermissionGateway; this covers notifications only.
// See PLAN.md 8.2 and S07.
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pontual/core/logging/log.dart';

/// Requests the notification permission on Android, best effort.
/// No-op on web and non-Android platforms. Never throws.
Future<bool> ensureNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return true;
  }
  try {
    if ((await Permission.notification.status).isGranted) {
      return true;
    }
    // On Android only the request() outcome is meaningful: status never
    // reports permanentlyDenied, so denial handling keys off this result.
    // A denial only hides the banner; sharing continues regardless.
    final PermissionStatus after = await Permission.notification.request();
    if (!after.isGranted) {
      Log.w('notifications denied', 'trip continues without banner');
      return false;
    }
    return true;
  } catch (_) {
    Log.w('notification request failed', 'trip continues');
    return false;
  }
}

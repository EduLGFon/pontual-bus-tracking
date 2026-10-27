// Share-trip entry: consent sheet, permission education, controller
// start, then the trip screen. MapTab buttons call shareTrip and do
// nothing else. Only pilot lines can share. A phased progress sheet
// covers the silent part (register, GPS, start) so a tap never ends
// with nothing. See PLAN.md S06, S07, S08.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/config/env.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/trip/share_phases.dart';
import 'package:pontual/features/trip/consent_sheet.dart';
import 'package:pontual/features/trip/location_service.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/share_progress_sheet.dart';
import 'package:pontual/features/trip/share_progress_tracker.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/android/notification_permission.dart';
import 'package:pontual/platform/android/permission_gateway.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Starts sharing a trip on [line]. Shows consent and permission UI,
/// then a phased progress sheet for the network and GPS steps, and
/// navigates to /trip on success. Declines stay silent; failures keep
/// the progress sheet open with the reason and a retry action.
/// Takes the provider [container], not a WidgetRef: callers (the dock)
/// may unmount mid-flow, and reading through a disposed ref throws.
/// [gateway] and [ensureNotifications] are injectable for tests:
/// production uses geolocator and the notification permission request,
/// tests pass fakes so no platform channel is ever touched.
Future<void> shareTrip(
  BuildContext context,
  ProviderContainer container,
  StaticLine line, {
  PermissionGateway gateway = const GeolocatorPermissionGateway(),
  Future<bool> Function() ensureNotifications = ensureNotificationPermission,
  bool legacySheets = true,
  int? consentVersion,
  // The new UI passes a callback that consumes its first disclosure and
  // presents another one if a later retry sees a newer consent version.
  // Null keeps the legacy ConsentSheet behavior.
  Future<bool> Function()? consentAnswer,
}) async {
  if (!line.pilot) {
    return;
  }
  try {
    await _shareTrip(
      context,
      container,
      line,
      gateway,
      ensureNotifications,
      legacySheets: legacySheets,
      consentAnswer: consentAnswer,
      consentVersion: consentVersion,
    );
  } catch (_) {
    // Any unexpected failure (for example the flags fetch throwing
    // before the progress sheet opens) ends here with an explanation,
    // never silently.
    if (!context.mounted) {
      return;
    }
    _tell(context, UiStrings.shareNoConnection);
  }
}

/// Share body; throws nothing, but the caller guards anyway.
Future<void> _shareTrip(
  BuildContext context,
  ProviderContainer container,
  StaticLine line,
  PermissionGateway gateway,
  Future<bool> Function() ensureNotifications, {
  bool legacySheets = true,
  Future<bool> Function()? consentAnswer,
  int? consentVersion,
}) async {
  if (!await gateway.servicesOn()) {
    // The new UI renders its own services-off card through the caller,
    // so the legacy sheet is skipped there but nowhere else.
    if (!legacySheets) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      // Root navigator so the sheet slides above the shell dock pill. D-U26.
      useRootNavigator: true,
      builder: (BuildContext context) => const LocationOffSheet(),
    );
    return;
  }
  final RemoteConfigRepository remote = await container.read(
    remoteConfigRepoProvider.future,
  );
  final int currentConsentVersion;
  if (consentVersion != null) {
    currentConsentVersion = consentVersion;
  } else {
    // Retries must not reuse a stale version: consent changes are a
    // server-side start gate and require a fresh disclosure.
    final Result<bool> refreshed = await remote.refresh(force: true);
    if (!context.mounted) {
      return;
    }
    if (refreshed is Err<bool>) {
      _tell(context, UiStrings.shareNoConnection);
      return;
    }
    currentConsentVersion = (await remote.current()).consentVersion;
  }
  final TripController controller = TripController(
    TripDeps(
      api: container.read(busApiProvider),
      gateway: gateway,
      consentStore: const ConsentStore(),
      consentVersion: currentConsentVersion,
      locations: LocationService.production,
      clock: SystemClock(),
    ),
  );
  if (!context.mounted) {
    controller.dispose();
    return;
  }
  final ShareProgressTracker tracker = ShareProgressTracker(
    lineId: line.id,
    consentVersion: currentConsentVersion,
    host: _hostOf(apiBaseUrl),
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
  tracker.report(SharePhase.services, SharePhaseStatus.done);
  tracker.report(SharePhase.config, SharePhaseStatus.done);
  bool sheetOpen = false;
  void openSheet() {
    if (sheetOpen || !context.mounted) {
      return;
    }
    sheetOpen = true;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        enableDrag: false,
        isDismissible: false,
        // Root navigator so the sheet slides above the shell dock pill. D-U26.
        useRootNavigator: true,
        builder: (BuildContext context) => ShareProgressSheet(
          tracker: tracker,
          lineLabel: line.name,
          onCancel: () {
            sheetOpen = false;
            tracker.cancel();
            controller.cancelStart();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          onRetry: () {
            sheetOpen = false;
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            unawaited(
              shareTrip(
                context,
                container,
                line,
                gateway: gateway,
                ensureNotifications: ensureNotifications,
                // The retry belongs to the flow that opened this sheet:
                // dropping the flags would fall back to the legacy sheets.
                legacySheets: legacySheets,
                consentAnswer: consentAnswer,
              ),
            );
          },
          onClose: () {
            sheetOpen = false;
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ).then((_) => sheetOpen = false),
    );
  }

  final bool started = await controller.startTrip(
    lineId: line.id,
    lineLabel: line.name,
    showConsent: () async {
      if (consentAnswer != null) {
        return consentAnswer();
      }
      if (!context.mounted) {
        return false;
      }
      return await ConsentSheet.show(context) == ConsentChoice.accepted;
    },
    showPermissions: () async {
      if (!context.mounted) {
        return;
      }
      // Best effort and non-blocking: the trip works without the banner.
      // The notification request always runs; only its education sheet
      // is owned by the new UI when it leads the flow.
      final bool notificationsGranted = await ensureNotifications();
      if (!context.mounted) {
        return;
      }
      if (!notificationsGranted) {
        // Surface a denied notification permission instead of failing
        // silently: without the foreground banner Android may kill the
        // sharing process when the app leaves the foreground.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(UiStrings.notificationNote)),
        );
      }
      if (!context.mounted || !legacySheets) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        // Root navigator so the sheet slides above the shell dock pill. D-U26.
        useRootNavigator: true,
        builder: (BuildContext context) => const PermissionInfoSheet(),
      );
    },
    onPhase: (SharePhase phase, SharePhaseStatus status, {String? errorCode}) {
      tracker.report(phase, status, errorCode: errorCode);
      if (phase == SharePhase.register) {
        openSheet();
      }
    },
  );
  if (!context.mounted) {
    controller.dispose();
    return;
  }
  if (started) {
    if (sheetOpen) {
      sheetOpen = false;
      // Root navigator: the sheet opened above the shell dock pill, so
      // only the root pop reaches it. A branch pop here is a silent
      // no-op that strands the stale sheet over the trip screen.
      Navigator.of(context, rootNavigator: true).pop();
    }
    // Push, not go: minimize and system back pop back to the screen that
    // opened the trip (DECISIONS.md#D77).
    unawaited(context.push('/trip', extra: controller));
    return;
  }
  final StartFailure? reason = controller.failReason;
  // Register, GPS, and start failures already show in the open progress
  // sheet with a retry action; only pre-sheet failures need handling
  // here. Declines stay silent.
  if (sheetOpen) {
    controller.dispose();
    return;
  }
  controller.dispose();
  if (!context.mounted) {
    return;
  }
  if (reason == StartFailure.declined) {
    return;
  }
  if (reason == StartFailure.permission) {
    // The new UI maps the denial to its own permission card; the legacy
    // sheets below only run for the legacy flow. The controller is
    // already disposed above, so this branch only returns.
    if (!legacySheets) {
      return;
    }
    final LocationPermissionState perm = await gateway.check();
    if (!context.mounted) {
      return;
    }
    if (perm == LocationPermissionState.permanentlyDenied) {
      await showModalBottomSheet<void>(
        context: context,
        // Root navigator so the sheet slides above the shell dock pill. D-U26.
        useRootNavigator: true,
        builder: (BuildContext context) => const PermissionBlockedSheet(),
      );
    } else if (perm == LocationPermissionState.denied) {
      await showModalBottomSheet<void>(
        context: context,
        // Root navigator so the sheet slides above the shell dock pill. D-U26.
        useRootNavigator: true,
        builder: (BuildContext context) => const PermissionDeniedSheet(),
      );
    }
    return;
  }
  if (reason == StartFailure.imprecise && !legacySheets) {
    // The new UI maps this to its own permission card; the snackbar
    // below only serves the legacy flow.
    return;
  }
  _tell(context, _messageFor(reason));
}

/// Maps a start failure to the message shown to the user.
String _messageFor(StartFailure? reason) {
  switch (reason) {
    case StartFailure.offline:
      return UiStrings.shareNoConnection;
    case StartFailure.noGps:
      return UiStrings.shareNoGps;
    case StartFailure.busy:
      return UiStrings.shareBusy;
    case StartFailure.outsideArea:
      return UiStrings.shareOutsideArea;
    case StartFailure.imprecise:
      return UiStrings.impreciseLocation;
    case StartFailure.permission:
    case StartFailure.declined:
    case StartFailure.failed:
    case null:
      return UiStrings.shareStartFailed;
  }
}

/// Host of the API base URL for the technical details. Host only.
String _hostOf(String baseUrl) {
  try {
    return Uri.parse(baseUrl).host;
  } catch (_) {
    return '-';
  }
}

/// Shows a short explanation where the tap happened. No-op without a
/// Scaffold (tests); production call sites always have one.
void _tell(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message)));
}

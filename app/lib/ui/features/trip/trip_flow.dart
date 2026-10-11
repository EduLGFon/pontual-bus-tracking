// Trip flow of the new UI: line chooser, consent disclosure, permission
// pre-prompt, then the existing share flow. This is the only place that
// starts a trip. PRIVACY: the disclosure sheet writes nothing; the choice
// is recorded exactly once by the existing share flow. This file never
// logs and never displays a rider.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/config/remote_config.dart';
import 'package:pontual/data/prefs/consent_store.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/features/trip/permission_sheet.dart';
import 'package:pontual/features/trip/share_flow.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/platform/android/notification_permission.dart';
import 'package:pontual/platform/android/permission_gateway.dart';
import 'package:pontual/platform/web/user_agent.dart';
import 'package:pontual/ui/design/components/permission_card.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/shell/trip_host.dart';
import 'package:pontual/ui/util/platform.dart';

import 'line_chooser_sheet.dart';
import 'permission_sheets.dart';

/// Starts sharing a trip on [line]. When [line] is null the rider picks a
/// line first. Steps: chooser, consent disclosure, permission pre-prompt,
/// then the existing share flow, which owns the OS prompt, the progress
/// sheet, and the navigation to /trip. Declines and dismissals are silent:
/// nothing is logged and no state changes behind the rider.
Future<void> startShare(
  BuildContext context,
  WidgetRef ref,
  LineVM? line, {
  PermissionGateway gateway = const GeolocatorPermissionGateway(),
  Future<void> Function() ensureNotifications = ensureNotificationPermission,
}) async {
  final LineVM? chosen = line ?? await _chooseLine(context);
  if (chosen == null) {
    return;
  }
  final StaticLine? target = await _staticLineOf(ref, chosen.key);
  if (target == null || !target.pilot) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  // The disclosure is presented before the first trip and whenever the
  // consent version changes; a rider who already accepted it goes
  // straight to the permission pre-prompt.
  if (await _consentNeeded(ref)) {
    if (!context.mounted || !await _consentStep(context)) {
      return;
    }
  }
  if (!context.mounted) {
    return;
  }
  await _permissionStep(
    context,
    ref,
    target,
    chosen,
    gateway,
    ensureNotifications,
  );
}

/// True while the rider has to accept the current consent version. Reads
/// the same store and version the share flow uses; it never writes them.
Future<bool> _consentNeeded(WidgetRef ref) async {
  try {
    final RemoteConfigRepository config = await ref.read(
      remoteConfigRepoProvider.future,
    );
    final int version = (await config.current()).consentVersion;
    return !await const ConsentStore().covers(version);
  } on Object {
    // Flags unavailable: ask, the safest answer.
    return true;
  }
}

/// Attaches a started controller to the trip host so the dock and the trip
/// screen read the same instance. Called by the /trip route, the only place
/// that receives the controller created by the share flow.
void attachTripController(WidgetRef ref, TripController controller) {
  ref.read(tripHostProvider.notifier).attach(controller);
}

/// Detaches the controller once the trip screen is gone and no trip runs.
/// A live trip keeps its host, so minimising the screen leaves the dock
/// working and the controller alive.
void detachTripController(TripHost host, TripController controller) {
  host.detachIfIdle(controller);
}

/// Chooser step: sharing-capable lines, live ones first, searchable.
/// Returns null when the rider dismisses the sheet.
Future<LineVM?> _chooseLine(BuildContext context) async {
  final LineVM? chosen = await showModalBottomSheet<LineVM>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator so the sheet slides above the shell dock pill. D-U26.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) => Padding(
      // The chooser has a search field: keep the list above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: const LineChooserSheet(),
    ),
  );
  return chosen;
}

/// Consent step: the disclosure sheet. Returns true when the rider
/// accepts the disclosure; the existing share flow records the choice
/// through its own consent call when the trip starts.
Future<bool> _consentStep(BuildContext context) async {
  final bool? accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator so the sheet slides above the shell dock pill. D-U26.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) => const ConsentBody(),
  );
  return accepted == true;
}

/// Permission step: pre-prompt sheet, then the OS prompt through the
/// existing share flow. A permission failure renders the permission card
/// of the matrix in UI_SPEC 7.7 and offers the retry, which restarts here.
Future<void> _permissionStep(
  BuildContext context,
  WidgetRef ref,
  StaticLine target,
  LineVM line,
  PermissionGateway gateway,
  Future<void> Function() ensureNotifications,
) async {
  if (!await _prePromptStep(context)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final _PermissionRecorder recorder = _PermissionRecorder(gateway);
  await shareTrip(
    context,
    ref,
    target,
    gateway: recorder,
    ensureNotifications: ensureNotifications,
    legacySheets: false,
  );
  if (!context.mounted) {
    return;
  }
  final PermissionCardState? state = _cardStateOf(recorder);
  if (state == null) {
    return;
  }
  final bool retry = await _failureStep(context, state, recorder);
  if (retry && context.mounted) {
    await _permissionStep(
      context,
      ref,
      target,
      line,
      gateway,
      ensureNotifications,
    );
  }
}

/// Pre-prompt step: returns true only when the rider taps Continuar. A
/// dismissal or Cancelar stops the flow with no side effects.
Future<bool> _prePromptStep(BuildContext context) async {
  final bool? keepGoing = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator so the sheet slides above the shell dock pill. D-U26.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) => const PermissionPromptBody(),
  );
  return keepGoing == true;
}

/// Failure step: shows the permission card and returns true when the rider
/// asks to try again.
Future<bool> _failureStep(
  BuildContext context,
  PermissionCardState state,
  _PermissionRecorder recorder,
) async {
  final bool? retry = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Root navigator so the sheet slides above the shell dock pill. D-U26.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext sheetContext) => PontualSheet(
      child: PermissionCard(
        state: state,
        onRetry: () => Navigator.of(sheetContext).pop(true),
        onOpenSettings: () {
          unawaited(recorder.openSettings());
          Navigator.of(sheetContext).pop(false);
        },
      ),
    ),
  );
  return retry == true;
}

/// Maps the recorded outcome to the permission card state of the matrix.
/// Null when the flow never reached a permission failure.
PermissionCardState? _cardStateOf(_PermissionRecorder recorder) {
  // Services-off short-circuits before any prompt: the card still owes
  // the rider an explanation with the platform-correct action.
  if (!recorder.services) {
    return PermissionCardState.servicesOff;
  }
  if (!recorder.requested ||
      recorder.answer == LocationPermissionState.granted) {
    return null;
  }
  if (PlatformInfo.isWeb) {
    // Browsers expose no settings page: the card walks the rider through
    // the steps of the detected browser family and re-checks on retry.
    return browserFamilyOf(userAgent()) == BrowserFamily.unknown
        ? PermissionCardState.blocked
        : PermissionCardState.browserBlocked;
  }
  return recorder.answer == LocationPermissionState.permanentlyDenied
      ? PermissionCardState.blocked
      : PermissionCardState.denied;
}

/// Static line for [key], or null when the data has no such line. Only the
/// chooser deals in view-models; the share flow still owns the static data.
Future<StaticLine?> _staticLineOf(WidgetRef ref, String key) async {
  try {
    final List<StaticLine> lines = await ref.read(linesProvider.future);
    for (final StaticLine line in lines) {
      if (line.code == key) {
        return line;
      }
    }
  } on Object {
    // Without data the share flow reports the connection problem itself.
  }
  return null;
}

/// Wraps the OS gateway so the flow can tell which permission state the
/// existing share flow ended in and can open settings on its behalf.
class _PermissionRecorder implements PermissionGateway {
  /// Creates a recorder around the OS [gateway].
  _PermissionRecorder(this.gateway);

  /// Gateway that reaches the OS.
  final PermissionGateway gateway;

  /// True once the OS prompt ran.
  bool requested = false;

  /// Answer of the last prompt or check.
  LocationPermissionState answer = LocationPermissionState.denied;

  /// True while device location services are on.
  bool services = true;

  @override
  Future<LocationPermissionState> check() async {
    final LocationPermissionState state = await gateway.check();
    answer = state;
    return state;
  }

  @override
  Future<LocationPermissionState> request() async {
    requested = true;
    final LocationPermissionState state = await gateway.request();
    answer = state;
    return state;
  }

  @override
  Future<bool> servicesOn() async {
    services = await gateway.servicesOn();
    return services;
  }

  @override
  Future<void> openSettings() => gateway.openSettings();
}

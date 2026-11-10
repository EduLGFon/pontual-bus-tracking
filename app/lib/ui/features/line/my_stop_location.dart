// My-stop sheet: the privacy note first, then the explicit request.
// Opened from the personal-arrival prompt on the line screen. The OS or
// browser permission request fires only from the "Usar minha localização"
// tap, never when the sheet opens. No spinner: loading is a static label.
// See docs/ui/UI_SPEC.md 5 and the design contract section 5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/permission_card.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Opens the my-stop location sheet. Presenting the sheet never asks for
/// permission or a fix: only the `Usar minha localização` button does.
Future<void> showMyStopLocationSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // The root navigator owns the modal so the app shell, its dock and
    // bottom navigation stay out from behind the sheet.
    builder: (BuildContext context) => const _MyStopLocationSheet(),
  );
}

class _MyStopLocationSheet extends ConsumerStatefulWidget {
  const _MyStopLocationSheet();

  @override
  ConsumerState<_MyStopLocationSheet> createState() =>
      _MyStopLocationSheetState();
}

class _MyStopLocationSheetState extends ConsumerState<_MyStopLocationSheet> {
  bool _popping = false;

  void _request() {
    unawaited(ref.read(viewerFixProvider.notifier).request());
  }

  void _openSettings() {
    unawaited(ref.read(viewerPermissionGatewayProvider).openSettings());
  }

  void _pop() {
    Navigator.of(context).pop();
  }

  void _popWhenReady() {
    if (_popping) {
      return;
    }
    _popping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ViewerFixState fix = ref.watch(viewerFixProvider);
    final bool web = ref.watch(viewerIsWebProvider);
    if (fix.status == ViewerFixStatus.ready) {
      _popWhenReady();
      return const PontualSheet(
        title: UiStrings.myStopPrivacyTitle,
        child: SizedBox.shrink(),
      );
    }
    return PontualSheet(
      title: UiStrings.myStopPrivacyTitle,
      scrollable: true,
      child: switch (fix.status) {
        ViewerFixStatus.idle => _Ask(
          body: UiStrings.myStopPrivacyBody,
          onRequest: _request,
          onNotNow: _pop,
        ),
        ViewerFixStatus.requesting => _Ask(
          body: UiStrings.myStopPrivacyBody,
          onRequest: _request,
          onNotNow: _pop,
          loading: true,
        ),
        ViewerFixStatus.denied => PermissionCard(
          state: web
              ? PermissionCardState.browserBlocked
              : PermissionCardState.denied,
          messageOverride: web ? null : UiStrings.myStopPermissionDenied,
          onRetry: _request,
        ),
        ViewerFixStatus.blocked => PermissionCard(
          state: PermissionCardState.blocked,
          messageOverride: UiStrings.myStopBlocked,
          onOpenSettings: _openSettings,
          onRetry: _request,
        ),
        ViewerFixStatus.imprecise => PermissionCard(
          state: PermissionCardState.imprecise,
          messageOverride: UiStrings.myStopImprecise,
          onOpenSettings: _openSettings,
          onRetry: _request,
        ),
        ViewerFixStatus.servicesOff => PermissionCard(
          state: PermissionCardState.servicesOff,
          messageOverride: UiStrings.myStopServicesOff,
          onOpenSettings: _openSettings,
          onRetry: _request,
        ),
        ViewerFixStatus.outsideArea => _RetryCard(
          message: UiStrings.myStopOutsideArea,
          onRetry: _request,
          onNotNow: _pop,
        ),
        ViewerFixStatus.error => _RetryCard(
          message: UiStrings.myStopTimeout,
          onRetry: _request,
          onNotNow: _pop,
        ),
        ViewerFixStatus.ready => const SizedBox.shrink(),
      },
    );
  }
}

/// Privacy note with the two actions. `loading` swaps the primary label
/// for the static seeking copy and disables it; no spinner anywhere.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.body,
    required this.onRequest,
    required this.onNotNow,
    this.loading = false,
  });

  /// Privacy copy shown before any request.
  final String body;

  /// Starts the explicit flow.
  final VoidCallback onRequest;

  /// Closes the sheet without asking anything.
  final VoidCallback onNotNow;

  /// Static "seeking" state while the fix is in flight.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(body, style: context.text.body),
        const SizedBox(height: Space.x4),
        PrimaryButton(
          label: loading
              ? UiStrings.myStopLoading
              : UiStrings.myStopUseLocation,
          onPressed: loading ? null : onRequest,
          loading: loading,
        ),
        const SizedBox(height: Space.x2),
        SecondaryButton(label: UiStrings.myStopNotNow, onPressed: onNotNow),
      ],
    );
  }
}

/// Honest failure card for the area and timeout states, with retry.
class _RetryCard extends StatelessWidget {
  const _RetryCard({
    required this.message,
    required this.onRetry,
    required this.onNotNow,
  });

  /// Failure copy in pt-BR.
  final String message;

  /// Runs the same explicit flow again.
  final VoidCallback onRetry;

  /// Closes the sheet.
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message, style: context.text.body),
          const SizedBox(height: Space.x4),
          PrimaryButton(label: UiStrings.retry, onPressed: onRetry),
          const SizedBox(height: Space.x2),
          SecondaryButton(label: UiStrings.myStopNotNow, onPressed: onNotNow),
        ],
      ),
    );
  }
}

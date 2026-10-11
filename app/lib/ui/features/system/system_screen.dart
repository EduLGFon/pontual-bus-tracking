// System screens of the new UI: maintenance, update required, server
// unavailable, and not found. Blocking states never hide timetables that
// are already on screen: each one keeps a way back to the app, shows no
// stack trace, and logs nothing with personal data.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Kinds of blocking system states. The router passes the path segment as
/// a string, so [SystemScreen] accepts either form.
enum SystemKind {
  /// Planned maintenance or kill switch.
  maintenance,

  /// Installed version below min_app_version.
  updateRequired,

  /// Server unreachable for about 60 seconds.
  unavailable,

  /// Unknown route, or /trip opened without a controller.
  notFound,
}

/// Resolves a route value into a [SystemKind]. Unknown values render the
/// not-found state instead of crashing on an unexpected URL.
SystemKind systemKindOf(Object raw) {
  if (raw is SystemKind) {
    return raw;
  }
  if (raw is String) {
    for (final SystemKind value in SystemKind.values) {
      if (value.name == raw) {
        return value;
      }
    }
  }
  return SystemKind.notFound;
}

/// Blocking system screen (UI_SPEC 7.9).
class SystemScreen extends StatelessWidget {
  /// Creates a system screen for [kind] with an optional pt-BR [message].
  const SystemScreen({required this.kind, this.message = '', super.key});

  /// Which blocking state to show. Accepts a [SystemKind] or the route
  /// path segment, because the router passes the string from the URL.
  final Object kind;

  /// Optional message from the remote config.
  final String message;

  @override
  Widget build(BuildContext context) {
    final SystemKind state = systemKindOf(kind);
    final String title = switch (state) {
      SystemKind.maintenance => UiStrings.maintenanceTitle,
      SystemKind.updateRequired => UiStrings.updateTitle,
      SystemKind.unavailable => UiStrings.serverDownTitle,
      SystemKind.notFound => UiStrings.notFoundTitle,
    };
    final EmptyArt art = state == SystemKind.maintenance
        ? EmptyArt.wrench
        : EmptyArt.cloud;
    final String body = message.isNotEmpty
        ? message
        : switch (state) {
            SystemKind.maintenance ||
            SystemKind.updateRequired => UiStrings.maintenanceBody,
            SystemKind.unavailable => UiStrings.serverDownBody,
            SystemKind.notFound => UiStrings.genericError,
          };
    // Every state keeps a way back into the app, and the timetables stay
    // one tap away while the live service is down.
    final ({String label, String to}) primary = switch (state) {
      SystemKind.maintenance => (label: UiStrings.seeTimetable, to: '/lines'),
      SystemKind.updateRequired => (
        label: PlatformInfo.isWeb
            ? UiStrings.reloadAction
            : UiStrings.updateAction,
        to: '/',
      ),
      SystemKind.unavailable => (label: UiStrings.retry, to: '/'),
      SystemKind.notFound => (label: UiStrings.navHome, to: '/'),
    };
    final ({String label, String to})? secondary = switch (state) {
      SystemKind.maintenance => (label: UiStrings.retry, to: '/'),
      SystemKind.unavailable => (label: UiStrings.seeTimetable, to: '/lines'),
      SystemKind.updateRequired || SystemKind.notFound => null,
    };
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(marginFor(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              EmptyState(
                title: title,
                message: body,
                art: art,
                actionLabel: primary.label,
                onAction: () => context.go(primary.to),
                secondaryLabel: secondary?.label,
                onSecondary: secondary == null
                    ? null
                    : () => context.go(secondary.to),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

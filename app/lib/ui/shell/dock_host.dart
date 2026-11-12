// Dock host: renders the trip dock with the label that fits the screen it
// appears on. A line screen passes "Estou neste ônibus"; the shell only
// renders the active bar and asks for `showIdle: false`. The host rebuilds
// on every controller notification, so the elapsed time and the phase are
// always fresh: a plain provider snapshot would freeze the dock at attach
// time. See docs/ui/UI_SPEC.md 7.1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pontual/features/trip/trip_controller.dart';
import 'package:pontual/ui/adapters/trip_adapter.dart';
import 'package:pontual/ui/design/components/trip_dock.dart';
import 'package:pontual/ui/features/trip/trip_flow.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/trip_vm.dart';
import 'package:pontual/ui/shell/trip_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// The global trip dock.
class DockHost extends StatelessWidget {
  /// Creates the host.
  const DockHost({
    required this.trip,
    this.onTap,
    this.idleLabel = UiStrings.dockIdle,
    super.key,
  });

  /// Trip state to render.
  final TripVM trip;

  /// Opens the trip screen, or the flow when idle.
  final VoidCallback? onTap;

  /// Idle label.
  final String idleLabel;

  @override
  Widget build(BuildContext context) {
    return TripDock(trip: trip, idleLabel: idleLabel, onTap: onTap);
  }
}

/// Live dock: watches the trip host and rebuilds on every notification of
/// the attached controller. Idle taps start the share flow (with the bound
/// line when one is set, otherwise the chooser opens); active taps go to
/// the trip screen. With [showIdle] false it renders nothing while no trip
/// is running, which lets the shell keep only the active bar in layout.
class LiveDockHost extends ConsumerWidget {
  /// Creates the live host.
  const LiveDockHost({
    this.idleLabel = UiStrings.dockIdle,
    this.boundLine,
    this.showIdle = true,
    super.key,
  });

  /// Idle label.
  final String idleLabel;

  /// Line the dock is bound to, set by the line screen only.
  final LineVM? boundLine;

  /// Whether the idle CTA renders when no trip is running. The line screen
  /// keeps it; the shell requests the active bar only.
  final bool showIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripController? controller = ref.watch(tripHostProvider);
    if (controller == null) {
      if (!showIdle) {
        return const SizedBox.shrink();
      }
      return DockHost(
        trip: const TripVM(phase: TripPhase.idle),
        idleLabel: idleLabel,
        onTap: () => startShare(context, boundLine),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final TripVM trip = tripVmOf(controller);
        if (!showIdle && !trip.inProgress) {
          return const SizedBox.shrink();
        }
        return DockHost(
          trip: trip,
          idleLabel: idleLabel,
          // The trip route boots from the controller in extra: without
          // it the router renders not-found and the live trip is lost.
          // Push so minimizing returns to the screen the dock was on
          // (DECISIONS.md#D77). Never stack a second /trip on top of
          // the live one: two routes would share one controller and the
          // attach/dispose ordering could tear down the live service.
          onTap: () {
            final String loc = GoRouterState.of(context).uri.path;
            if (loc == '/trip') {
              return;
            }
            context.push('/trip', extra: controller);
          },
        );
      },
    );
  }
}

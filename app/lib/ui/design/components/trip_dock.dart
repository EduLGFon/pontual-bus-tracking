// TripDock: the global pill above the bottom navigation. Idle shows the CTA,
// active shows a live bar with the elapsed time, and problem states are
// amber. No destructive action lives on the bar.
// See docs/ui/UI_SPEC.md 7.1.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/trip_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// The dock.
class TripDock extends StatelessWidget {
  /// Creates the dock.
  const TripDock({
    required this.trip,
    required this.idleLabel,
    this.onTap,
    this.maxWidth = 420,
    super.key,
  });

  /// Trip state to render.
  final TripVM trip;

  /// Idle label: UiStrings.dockIdle or UiStrings.dockIdleOnLine.
  final String idleLabel;

  /// Called when the dock is tapped.
  final VoidCallback? onTap;

  /// Maximum width on large screens.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bool active = trip.inProgress;
    final bool problem =
        trip.phase == TripPhase.reconnecting || trip.phase == TripPhase.paused;
    final Color accent = problem ? colors.warning : colors.live;
    final Color fill = active ? colors.surfaceRaised : colors.primary;
    final Color labelColor = active ? colors.ink : colors.onPrimary;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Pressable(
            onTap: trip.phase == TripPhase.starting ? null : onTap,
            semanticLabel: _semanticLabel(),
            borderRadius: Radii.pill,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: Sizes.dock,
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: active
                    ? Border.all(color: accent)
                    : Border.all(color: colors.bg),
              ),
              // The pill hugs its content: icon plus label plus chevron
              // with the horizontal margins only. Flexible (never Expanded)
              // still ellipsises a long active label on narrow screens.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (active) ...<Widget>[
                    const LiveDot(certainty: Certainty.live, size: 8),
                    const SizedBox(width: Space.x2),
                  ],
                  Flexible(
                    child: Text(
                      active ? _activeLabel() : idleLabel,
                      style: PontualText.label.copyWith(color: labelColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Icon(Icons.expand_more_rounded, size: 20, color: labelColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _activeLabel() {
    final String message = _messageOf(trip.phase);
    if (trip.phase == TripPhase.active && trip.lineLabel.isNotEmpty) {
      return '$message · ${trip.lineLabel}';
    }
    return message;
  }

  String _messageOf(TripPhase phase) {
    return switch (phase) {
      TripPhase.idle => idleLabel,
      TripPhase.starting => UiStrings.dockStarting,
      TripPhase.active => UiStrings.dockSharing,
      TripPhase.reconnecting => UiStrings.dockReconnecting,
      TripPhase.paused => UiStrings.dockGpsOff,
    };
  }

  String _semanticLabel() {
    if (trip.phase == TripPhase.idle) {
      return idleLabel;
    }
    return '${_activeLabel()}. ${UiStrings.tripTitle}';
  }
}

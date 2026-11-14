// Header of the line sheet: the line badge with its Hero tag, the name, the
// terminals, the certainty status line and the favourite star. The next
// departure is owned by the hero below, so this header no longer repeats
// it. Kept apart from the sheet body so both stay small and focused.
// See docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/lines/favorites_store_bridge.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Certainty shown by the header chip: live when a fresh position exists,
/// predicted when the newest value is a labeled estimate, stale when
/// every position is old, and scheduled for a timetable-only line.
/// Never mixes two certainties in one number.
Certainty statusCertaintyOf(List<VehicleVM> vehicles) {
  if (vehicles.isEmpty) {
    return Certainty.scheduled;
  }
  for (final VehicleVM v in vehicles) {
    if (v.certainty == Certainty.live) {
      return Certainty.live;
    }
  }
  for (final VehicleVM v in vehicles) {
    if (v.certainty == Certainty.predicted) {
      return Certainty.predicted;
    }
  }
  return Certainty.stale;
}

/// pt-BR word of a certainty, so the chip never travels by colour alone.
String certaintyWordOf(Certainty value) {
  return switch (value) {
    Certainty.live => UiStrings.certaintyLive,
    Certainty.predicted => UiStrings.certaintyPredicted,
    Certainty.scheduled => UiStrings.certaintyScheduled,
    Certainty.stale => UiStrings.certaintyStale,
  };
}

/// Line header: badge, name, terminals, status line and the favourite star.
class LineSheetHeader extends StatelessWidget {
  /// Creates the header.
  const LineSheetHeader({
    required this.line,
    required this.vehicles,
    this.hasUpcomingToday = true,
    super.key,
  });

  /// Line view-model shown by the header.
  final LineVM line;

  /// Vehicles of the line, for the status line.
  final List<VehicleVM> vehicles;

  /// Whether the timetable still has a departure later today. When false,
  /// a shareable line says the day is over instead of pointing at the
  /// empty hero. Defaults to true so other call sites keep the old copy.
  final bool hasUpcomingToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String terminals = line.terminalsText;
    final bool showTerminals = shouldShowTerminals(line.name, line.terminals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LineBadge.ofLine(
              line,
              size: BadgeSize.l,
              heroTag: 'line-badge-${line.key}',
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    line.name,
                    style: context.text.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (terminals.isNotEmpty && showTerminals) ...<Widget>[
                    const SizedBox(height: Space.x1),
                    Text(terminals, style: context.text.caption),
                  ],
                ],
              ),
            ),
            LineStarButton(lineKey: line.key, short: line.short),
          ],
        ),
        const SizedBox(height: Space.x2),
        // Full width so the certainty badge and the live count do not
        // wrap into each other in the narrow side panel.
        _StatusLine(
          line: line,
          vehicles: vehicles,
          hasUpcomingToday: hasUpcomingToday,
        ),
        if (!line.supportsSharing) ...<Widget>[
          const SizedBox(height: Space.x1),
          Text(
            UiStrings.lineNoTracking,
            style: context.text.caption.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// Status line: the certainty word plus the live count or, without live
/// buses, the source of the hero departure. Never repeats the empty-live
/// sentence that the body card owns.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.line,
    required this.vehicles,
    required this.hasUpcomingToday,
  });

  /// Line described by the line.
  final LineVM line;

  /// Vehicles of the line.
  final List<VehicleVM> vehicles;

  /// Whether a departure is still ahead today.
  final bool hasUpcomingToday;

  @override
  Widget build(BuildContext context) {
    final Certainty certainty = statusCertaintyOf(vehicles);
    final int liveCount = vehicles
        .where((VehicleVM v) => v.certainty == Certainty.live)
        .length;
    final String subtitle = liveCount > 0
        ? UiStrings.lineLiveCount(liveCount)
        : !line.supportsSharing
        ? UiStrings.onlyTimetable
        : !hasUpcomingToday
        ? UiStrings.homeNoMoreToday
        : UiStrings.lineNextScheduled;
    return Semantics(
      label: '${certaintyWordOf(certainty)}. $subtitle',
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.x2,
        runSpacing: Space.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          CertaintyBadge(certainty: certainty),
          Text(
            subtitle,
            style: context.text.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Favourite toggle backed by the shared favourites provider, so the header,
/// the lines list and the filter always agree.
class LineStarButton extends ConsumerWidget {
  /// Creates the toggle.
  const LineStarButton({required this.lineKey, this.short, super.key});

  /// Stable line key of the toggle.
  final String lineKey;

  /// Badge text used by the per-line semantics, empty when unknown.
  final String? short;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lineKey.isEmpty) {
      return const SizedBox.shrink();
    }
    final bool favorite = ref.watch(favoritesProvider).contains(lineKey);
    final String text = (short ?? '').isEmpty
        ? (favorite ? UiStrings.unfavorite : UiStrings.favorite)
        : (favorite
              ? UiStrings.unfavoriteLine(short!)
              : UiStrings.favoriteLine(short!));
    return IconBtn(
      icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
      semanticLabel: text,
      tooltip: text,
      selected: favorite,
      iconSize: 22,
      onTap: () {
        HapticFeedback.selectionClick();
        unawaited(ref.read(favoritesProvider.notifier).toggle(lineKey));
        ref
            .read(toastControllerProvider.notifier)
            .show(
              favorite ? UiStrings.linesFavRemoved : UiStrings.linesFavAdded,
              actionLabel: UiStrings.undo,
              onAction: () => unawaited(
                ref.read(favoritesProvider.notifier).toggle(lineKey),
              ),
            );
      },
    );
  }
}

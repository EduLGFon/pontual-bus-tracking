// Header of the line sheet: the line badge with its Hero tag, the name, the
// terminals, the certainty status chip and the favourite star. Kept apart
// from the sheet body so both stay small and focused.
// See docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
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
import 'package:pontual/ui/util/format_eta.dart';

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

/// Line header: badge, name, terminals, status chip and the favourite star.
class LineSheetHeader extends StatelessWidget {
  /// Creates the header.
  const LineSheetHeader({
    required this.line,
    required this.vehicles,
    required this.status,
    this.onOpenTimetable,
    super.key,
  });

  /// Line view-model shown by the header.
  final LineVM line;

  /// Vehicles of the line, for the status chip.
  final List<VehicleVM> vehicles;

  /// Shared timetable status driving the next-departure row.
  final LineStatus status;

  /// Called when the next-departure row is tapped.
  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String terminals = line.terminalsText;
    final bool showTerminals = shouldShowTerminals(line.name, line.terminals);
    return Row(
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
              const SizedBox(height: Space.x2),
              _StatusChip(line: line, vehicles: vehicles),
              const SizedBox(height: Space.x1),
              _NextRow(status: status, onOpenTimetable: onOpenTimetable),
              if (!line.supportsSharing) ...<Widget>[
                const SizedBox(height: Space.x1),
                Text(
                  UiStrings.lineNoTracking,
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ],
          ),
        ),
        LineStarButton(lineKey: line.key, short: line.short),
      ],
    );
  }
}

/// Status chip: the certainty word plus the offline-vehicle explanation.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.line, required this.vehicles});

  /// Line described by the chip.
  final LineVM line;

  /// Vehicles of the line.
  final List<VehicleVM> vehicles;

  @override
  Widget build(BuildContext context) {
    final Certainty certainty = statusCertaintyOf(vehicles);
    final String subtitle = line.supportsSharing
        ? UiStrings.homeNoLive
        : UiStrings.onlyTimetable;
    return Semantics(
      label: '${certaintyWordOf(certainty)}. $subtitle',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          CertaintyBadge(certainty: certainty),
          const SizedBox(width: Space.x2),
          Flexible(
            child: Text(
              subtitle,
              style: context.text.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Next-departure row: the shared status as a tappable chip when a time
/// is known, muted text otherwise. Tapping opens Horários (the timetable
/// tab auto-scrolls to the next departure itself).
class _NextRow extends StatelessWidget {
  /// Creates the row.
  const _NextRow({required this.status, this.onOpenTimetable});

  /// Shared timetable status.
  final LineStatus status;

  /// Called when a known departure is tapped.
  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    final String? label = _labelOf(status);
    if (label == null) {
      return const SizedBox.shrink();
    }
    if (_tappable(status) && onOpenTimetable != null) {
      return GhostLink(label: label, onTap: onOpenTimetable);
    }
    return Text(
      label,
      style: context.text.caption.copyWith(color: context.colors.inkMuted),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// True when the status carries a time worth opening the timetable for.
  bool _tappable(LineStatus value) {
    return switch (value.kind) {
      LineStatusKind.now ||
      LineStatusKind.imminent ||
      LineStatusKind.upcoming ||
      LineStatusKind.tomorrow => true,
      LineStatusKind.live ||
      LineStatusKind.noneToday ||
      LineStatusKind.noTimetable => false,
    };
  }

  /// Visible label of the status, null when nothing should render.
  String? _labelOf(LineStatus value) {
    switch (value.kind) {
      case LineStatusKind.live:
        return null;
      case LineStatusKind.now:
        return '${UiStrings.nextDeparture} ${value.time} · agora';
      case LineStatusKind.imminent:
        return '${UiStrings.nextDeparture} ${value.time} · '
            'em ${value.minutes} min';
      case LineStatusKind.upcoming:
        final int minutes = value.minutes ?? 0;
        final String countdown = minutes < 60
            ? 'em $minutes min'
            : 'em ${formatHours(minutes)}';
        return '${UiStrings.nextDeparture} ${value.time} · $countdown';
      case LineStatusKind.tomorrow:
        return UiStrings.homeTomorrowAt(value.time ?? '');
      case LineStatusKind.noneToday:
        return UiStrings.homeNoMoreToday;
      case LineStatusKind.noTimetable:
        return UiStrings.linesNoTimetable;
    }
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

// Header of the line sheet: the line badge with its Hero tag, the name, the
// terminals, the certainty status chip and the favourite star. Kept apart
// from the sheet body so both stay small and focused.
// See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Certainty shown by the header chip: live when a fresh position exists,
/// stale when every position is old, and scheduled for a timetable-only
/// line. Never mixes two certainties in one number.
Certainty statusCertaintyOf(List<VehicleVM> vehicles) {
  if (vehicles.isEmpty) {
    return Certainty.scheduled;
  }
  for (final VehicleVM v in vehicles) {
    if (v.certainty == Certainty.live) {
      return Certainty.live;
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
    super.key,
  });

  /// Line view-model shown by the header.
  final LineVM line;

  /// Vehicles of the line, for the status chip.
  final List<VehicleVM> vehicles;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String terminals = line.terminalsText;
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
              if (terminals.isNotEmpty) ...<Widget>[
                const SizedBox(height: Space.x1),
                Text(terminals, style: context.text.caption),
              ],
              const SizedBox(height: Space.x2),
              _StatusChip(line: line, vehicles: vehicles),
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
        LineStarButton(lineKey: line.key),
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

/// Favourite toggle backed by the local store.
class LineStarButton extends StatefulWidget {
  /// Creates the toggle.
  const LineStarButton({required this.lineKey, super.key});

  /// Stable line key of the toggle.
  final String lineKey;

  @override
  State<LineStarButton> createState() => _LineStarButtonState();
}

class _LineStarButtonState extends State<LineStarButton> {
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(LineStarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lineKey != oldWidget.lineKey) {
      _read();
    }
  }

  Future<void> _read() async {
    if (widget.lineKey.isEmpty) {
      return;
    }
    final Set<String> set = await const FavoritesStore().read();
    if (mounted) {
      setState(() => _favorite = set.contains(widget.lineKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lineKey.isEmpty) {
      return const SizedBox.shrink();
    }
    return IconBtn(
      icon: _favorite ? Icons.star_rounded : Icons.star_border_rounded,
      semanticLabel: _favorite ? UiStrings.unfavorite : UiStrings.favorite,
      selected: _favorite,
      iconSize: 22,
      onTap: () {
        final bool next = !_favorite;
        setState(() => _favorite = next);
        const FavoritesStore().toggle(widget.lineKey);
      },
    );
  }
}

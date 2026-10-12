// ShortcutCard: 156x112 card for a saved journey. Icon, two-line label,
// line badge, muted direction line and the next arrival with its state:
// upcoming, imminent (primary accent), live, no more today or no data.
// The empty variant is a ghost card with a dashed border that opens the
// add flow.
// See docs/ui/UI_SPEC.md 5 and 7.2 and docs/ui/home-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/dashed_outline.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/home/home_logic.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/shortcut_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// A shortcut card.
class ShortcutCard extends StatelessWidget {
  /// Creates a card.
  const ShortcutCard({
    required this.label,
    required this.line,
    this.arrival,
    this.now,
    this.icon = Icons.place_outlined,
    this.isLive = false,
    this.direction,
    this.tomorrowLabel,
    this.hasTimetable = true,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// Card label, for example "Casa".
  final String label;

  /// Line the shortcut points at.
  final LineVM line;

  /// Next arrival, when the timetable has one.
  final ArrivalVM? arrival;

  /// Current instant, required with [arrival].
  final DateTime? now;

  /// Leading icon chosen by the shortcut kind.
  final IconData icon;

  /// True when a bus on this line is being shared right now.
  final bool isLive;

  /// Muted second line, for example "sentido Centro". Null hides it.
  final String? direction;

  /// First departure of the next day (`HH:mm`), shown under the
  /// no-more-today state when known.
  final String? tomorrowLabel;

  /// False when the line has no usable timetable at all.
  final bool hasTimetable;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Called on long press, for the edit and remove sheet.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ArrivalVM? current = arrival;
    final DateTime? at = now;
    final ArrivalVM? timed = current != null && at != null ? current : null;
    final ShortcutCardState state = resolveShortcutState(
      isLive: isLive,
      next: timed,
      now: at,
      hasTimetable: hasTimetable,
    );
    final EtaFormat? format = timed == null || at == null
        ? null
        : formatEta(timed, at);
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: _semanticLabel(state, format),
      borderRadius: Radii.l,
      child: Container(
        width: Sizes.shortcutWidth,
        constraints: const BoxConstraints(minHeight: Sizes.shortcutHeight),
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: context.colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: context.colors.inkMuted),
                const SizedBox(width: Space.x1),
                Expanded(
                  // Long names wrap to two lines so cards that share a
                  // prefix (for example three "Faculdade ..." stops) stay
                  // distinguishable; the tooltip holds the full name.
                  child: Tooltip(
                    message: label,
                    child: Text(
                      label,
                      style: context.text.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: Space.x2),
                LineBadge.ofLine(line, size: BadgeSize.s),
              ],
            ),
            if (direction != null && direction!.isNotEmpty) ...<Widget>[
              const SizedBox(height: Space.x1),
              Text(
                direction!,
                style: context.text.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: Space.x2),
            // One screen-reader sentence per card: the time texts below
            // are excluded so they are not announced twice.
            ExcludeSemantics(child: _timeBlock(context, state, format)),
          ],
        ),
      ),
    );
  }

  Widget _timeBlock(
    BuildContext context,
    ShortcutCardState state,
    EtaFormat? format,
  ) {
    switch (state) {
      case ShortcutCardState.live:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LiveDot(certainty: Certainty.live),
            const SizedBox(width: Space.x1),
            Flexible(
              child: Text(
                UiStrings.certaintyLive,
                style: context.text.label.copyWith(
                  color: context.colors.liveText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case ShortcutCardState.imminent:
        // EtaText owns no accent variant, so the imminent state renders
        // its own tabular pair in the primary accent. Strings still come
        // from formatEta, never invented here.
        final EtaFormat current = format!;
        final Color accent = context.colors.primary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              current.primary,
              style: context.text.etaLarge.copyWith(color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            const SizedBox(height: 2),
            Text(
              current.secondary,
              style: context.text.caption.copyWith(color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      case ShortcutCardState.upcoming:
        final ArrivalVM? current = arrival;
        final DateTime? at = now;
        if (current == null || at == null) {
          return _restText(context, UiStrings.homeNoTime, null);
        }
        return EtaText.ofArrival(
          current,
          at,
          semanticLabel: '$label, linha ${line.name}',
        );
      case ShortcutCardState.noneToday:
        final String? tomorrow = tomorrowLabel;
        return _restText(
          context,
          UiStrings.homeNoMoreToday,
          tomorrow == null ? null : UiStrings.homeTomorrowAt(tomorrow),
        );
      case ShortcutCardState.noData:
        return _restText(
          context,
          UiStrings.homeNoTime,
          UiStrings.homeNoTimeHint,
        );
    }
  }

  Widget _restText(BuildContext context, String primary, String? secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          primary,
          style: context.text.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (secondary != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            secondary,
            style: context.text.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _semanticLabel(ShortcutCardState state, EtaFormat? format) {
    final String? short = line.short;
    final String linePart =
        short != null && short.isNotEmpty ? 'Linha $short' : line.name;
    final String? dir = direction;
    final String head = dir == null || dir.isEmpty
        ? '$linePart, $label'
        : '$linePart, $label, $dir';
    switch (state) {
      case ShortcutCardState.live:
        return '$head. ${UiStrings.certaintyLive}.';
      case ShortcutCardState.upcoming:
      case ShortcutCardState.imminent:
        return '$head. ${format?.a11y ?? ''}';
      case ShortcutCardState.noneToday:
        final String? tomorrow = tomorrowLabel;
        return tomorrow == null
            ? '$head. ${UiStrings.homeNoMoreToday}.'
            : '$head. ${UiStrings.homeNoMoreToday}. '
                  '${UiStrings.homeTomorrowAt(tomorrow)}.';
      case ShortcutCardState.noData:
        return '$head. ${UiStrings.homeNoTime}.';
    }
  }
}

/// Ghost card that opens the add flow with a kind preselected.
class AddShortcutCard extends StatelessWidget {
  /// Creates the card.
  const AddShortcutCard({
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    super.key,
  });

  /// Label in pt-BR, for example "Casa".
  final String label;

  /// Called on tap.
  final VoidCallback onTap;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: Radii.l,
      child: CustomPaint(
        painter: DashedOutline(
          color: colors.inkMuted,
          radius: Radii.l,
          strokeWidth: 1.5,
        ),
        child: Container(
          width: Sizes.shortcutWidth,
          constraints: const BoxConstraints(minHeight: Sizes.shortcutHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(Space.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 22, color: colors.inkMuted),
              const SizedBox(height: Space.x1),
              Text(
                label,
                style: context.text.caption.copyWith(color: colors.inkMuted),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon of a shortcut kind.
IconData iconOfKind(ShortcutKind kind) {
  return switch (kind) {
    ShortcutKind.home => Icons.home_rounded,
    ShortcutKind.work => Icons.work_outline_rounded,
    ShortcutKind.school => Icons.school_outlined,
    ShortcutKind.university => Icons.menu_book_outlined,
    ShortcutKind.custom => Icons.place_outlined,
  };
}

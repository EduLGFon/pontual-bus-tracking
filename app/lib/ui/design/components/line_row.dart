// LineRow: compact list row for the lines list. Badge, title, one status
// line that always exists, and a star toggle. Light divider rows, no heavy
// cards, so more rows fit per screen. Times use tabular figures and never
// touch the star. See docs/ui/UI_SPEC.md 5 and docs/ui/lines-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// A line in the list.
class LineRow extends StatelessWidget {
  /// Creates a row.
  const LineRow({
    required this.line,
    required this.status,
    this.onTap,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.semanticLabel,
    super.key,
  });

  /// Line to show.
  final LineVM line;

  /// Status driving the single status line. Always provided: live wins,
  /// then timetable states, never empty.
  final LineStatus status;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Star toggle, when the favorites feature is on.
  final VoidCallback? onToggleFavorite;

  /// True when the line is starred. Only read when [onToggleFavorite] is set.
  final bool isFavorite;

  /// Screen-reader sentence for the row. Defaults to a full pt-BR sentence.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool showStops = shouldShowTerminals(line.name, line.terminals);
    final String short = line.short ?? '';
    final String starLabel = short.isEmpty
        ? (isFavorite ? UiStrings.unfavorite : UiStrings.favorite)
        : (isFavorite
              ? UiStrings.unfavoriteLine(short)
              : UiStrings.favoriteLine(short));
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? _rowSemantics(short),
      borderRadius: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x4,
                vertical: Space.x3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  LineBadge.ofLine(line, size: BadgeSize.m),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          line.name,
                          style: context.text.headline,
                          maxLines: showStops ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showStops) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            line.terminalsText,
                            style: context.text.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        _statusLine(context),
                      ],
                    ),
                  ),
                  if (onToggleFavorite != null) ...<Widget>[
                    const SizedBox(width: Space.x2),
                    IconBtn(
                      icon: isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      semanticLabel: starLabel,
                      selected: isFavorite,
                      onTap: onToggleFavorite,
                      size: hitTarget,
                      iconSize: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.colors.line),
        ],
      ),
    );
  }

  /// The single status line, styled by kind with tabular figures for times.
  Widget _statusLine(BuildContext context) {
    final LineStatus current = status;
    switch (current.kind) {
      case LineStatusKind.live:
        final int count = line.liveVehicleCount;
        final String text = count > 1
            ? '${UiStrings.certaintyLive} · $count'
            : UiStrings.certaintyLive;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LiveDot(certainty: Certainty.live),
            const SizedBox(width: Space.x1),
            Flexible(
              child: Text(
                text,
                style: context.text.label.copyWith(
                  color: context.colors.liveText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case LineStatusKind.now:
        return Text(
          '${UiStrings.nextDeparture} ${current.time} · agora',
          style: _tabular(context.text.label).copyWith(
            color: context.colors.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.imminent:
        return Text(
          '${UiStrings.nextDeparture} ${current.time} · '
          'em ${current.minutes} min',
          style: _tabular(context.text.label).copyWith(
            color: context.colors.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.upcoming:
        final int minutes = current.minutes ?? 0;
        final String countdown = minutes < 60
            ? 'em $minutes min'
            : 'em ${formatHours(minutes)}';
        return Text(
          '${UiStrings.nextDeparture} ${current.time} · $countdown',
          style: _tabular(context.text.caption),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.tomorrow:
        return Text(
          UiStrings.homeTomorrowAt(current.time ?? ''),
          style: _tabular(context.text.caption),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.noneToday:
        return Text(
          UiStrings.homeNoMoreToday,
          style: context.text.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.noTimetable:
        return Text(
          UiStrings.linesNoTimetable,
          style: context.text.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  /// Full pt-BR sentence for screen readers.
  String _rowSemantics(String short) {
    final String linePart = short.isNotEmpty
        ? 'Linha $short, ${line.name}'
        : line.name;
    final LineCategory category = categoryFor(
      short: short,
      name: line.name,
      terminals: line.terminals,
      areaTags: line.areaTags,
    );
    final String head = '$linePart, região ${lineCategoryLabel(category)}';
    final String tail = switch (status.kind) {
      LineStatusKind.live => UiStrings.certaintyLive,
      LineStatusKind.now =>
        'próxima saída às ${status.time}, agora',
      LineStatusKind.imminent ||
      LineStatusKind.upcoming =>
        'próxima saída às ${status.time}, em ${_spokenMinutes(status.minutes)}',
      LineStatusKind.tomorrow => 'Amanhã ${status.time}',
      LineStatusKind.noneToday => UiStrings.homeNoMoreToday,
      LineStatusKind.noTimetable => UiStrings.linesNoTimetable,
    };
    final String fav = isFavorite ? ', favorita' : '';
    return '$head, $tail$fav.';
  }

  /// Tabular figures so countdown digits never jitter.
  TextStyle _tabular(TextStyle base) {
    return base.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Spoken minutes for semantics.
  String _spokenMinutes(int? minutes) {
    if (minutes == null) {
      return '';
    }
    if (minutes >= 60) {
      return formatHours(minutes);
    }
    return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
  }
}

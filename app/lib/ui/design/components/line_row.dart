// LineRow: compact list row for the lines list. Badge, title, one status
// line that always exists, and a star toggle. Light divider rows, no heavy
// cards, so more rows fit per screen. Times use tabular figures and never
// touch the star. See docs/ui/UI_SPEC.md 5 and docs/ui/lines-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/domain/line_category.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/line_status_line.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
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
                        LineStatusLine(
                          status: status,
                          liveCount: line.liveVehicleCount,
                        ),
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
      LineStatusKind.now => 'próxima saída às ${status.time}, agora',
      LineStatusKind.imminent || LineStatusKind.upcoming =>
        'próxima saída às ${status.time}, em ${_spokenMinutes(status.minutes)}',
      LineStatusKind.tomorrow => 'Amanhã ${status.time}',
      LineStatusKind.noneToday => UiStrings.homeNoMoreToday,
      LineStatusKind.noTimetable => UiStrings.linesNoTimetable,
    };
    final String fav = isFavorite ? ', favorita' : '';
    return '$head, $tail$fav.';
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

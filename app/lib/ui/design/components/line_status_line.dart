// One status line for a line row, shared by Linhas and Busca so the
// wording, colours and dot never diverge between screens. Live wins, then
// the timetable states; the line always shows something.
// See docs/ui/UI_SPEC.md 5 and docs/ui/lines-redesign.md.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_status.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// The single status line shown under a line name.
class LineStatusLine extends StatelessWidget {
  /// Creates the status line for [status].
  const LineStatusLine({required this.status, this.liveCount = 0, super.key});

  /// Status driving the line.
  final LineStatus status;

  /// Vehicles sharing on the line, appended to the live label when above one.
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    final LineStatus current = status;
    switch (current.kind) {
      case LineStatusKind.live:
        final String text = liveCount > 1
            ? '${UiStrings.certaintyLive} · $liveCount'
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
          style: _tabular(context.text.label)
              .copyWith(color: context.colors.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case LineStatusKind.imminent:
        return Text(
          '${UiStrings.nextDeparture} ${current.time} · '
          'em ${current.minutes} min',
          style: _tabular(context.text.label)
              .copyWith(color: context.colors.primary),
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

  /// Tabular figures so countdown digits never jitter.
  TextStyle _tabular(TextStyle base) {
    return base.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
}

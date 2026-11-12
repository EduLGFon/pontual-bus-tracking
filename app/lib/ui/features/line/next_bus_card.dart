// NextBusCard: the vertical scheduled/live hero of the line sheet. It owns
// the next departure when the personal arrival card is not the hero. A
// vertical layout avoids the fixed-width ETA block used by ArrivalRow,
// which clips in the narrow side panel. See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';

import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// Vertical next-bus hero: line identity, a large ETA, its certainty and
/// an optional timetable action.
class NextBusCard extends StatelessWidget {
  /// Creates the card.
  const NextBusCard({
    required this.line,
    required this.arrival,
    required this.now,
    this.onOpenTimetable,
    super.key,
  });

  /// Line the departure belongs to.
  final LineVM line;

  /// Departure shown as the hero.
  final ArrivalVM arrival;

  /// Current instant, São Mateus wall clock held as UTC.
  final DateTime now;

  /// Opens the Horários tab. Null hides the action.
  final VoidCallback? onOpenTimetable;

  @override
  Widget build(BuildContext context) {
    final EtaFormat format = formatEta(arrival, now);
    final bool past =
        arrival.certainty == Certainty.scheduled && arrival.isPast(now);
    final String? statusLabel = switch (arrival.certainty) {
      Certainty.live => UiStrings.lineNextLive,
      Certainty.scheduled => UiStrings.lineNextScheduled,
      _ => null,
    };
    final String terminals = line.terminalsText;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: '${UiStrings.lineNextTitle}. ${format.a11y}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // The ETA leads the card: the next bus is the first thing
                // the rider should see.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: EtaText(
                    primary: format.primary,
                    secondary: format.secondary,
                    hero: true,
                    dimmed: past,
                    semanticLabel: format.a11y,
                  ),
                ),
                const SizedBox(height: Space.x1),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    CertaintyBadge(certainty: arrival.certainty, dimmed: past),
                    if (statusLabel != null)
                      Text(statusLabel, style: context.text.caption),
                  ],
                ),
                const SizedBox(height: Space.x2),
                Row(
                  children: <Widget>[
                    LineBadge.ofLine(line, size: BadgeSize.m, dimmed: past),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            line.name,
                            style: context.text.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (terminals.isNotEmpty)
                            Text(
                              terminals,
                              style: context.text.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onOpenTimetable != null) ...<Widget>[
            const SizedBox(height: Space.x1),
            GhostLink(
              label: UiStrings.homeNextTimetableAction,
              icon: Icons.schedule_rounded,
              onTap: onOpenTimetable,
            ),
          ],
        ],
      ),
    );
  }
}

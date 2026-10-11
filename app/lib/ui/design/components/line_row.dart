// LineRow: compact list row for the lines list. Line badge, name, terminals
// subtitle, trailing live dot or ETA, and an optional star toggle.
// See docs/ui/UI_SPEC.md 5 and 7.4.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// A line in the list.
class LineRow extends StatelessWidget {
  /// Creates a row.
  const LineRow({
    required this.line,
    this.onTap,
    this.nextEta = '',
    this.onToggleFavorite,
    this.semanticLabel,
    super.key,
  });

  /// Line to show.
  final LineVM line;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Pre-formatted next departure, for example "12 min". Empty hides it.
  final String nextEta;

  /// Star toggle, when the favorites feature is on.
  final VoidCallback? onToggleFavorite;

  /// Screen-reader sentence for the row.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool live = line.isLive;
    final String subtitle = live
        ? '${line.liveVehicleCount} ${UiStrings.oneLive}'
        : (line.terminalsText.isNotEmpty
              ? line.terminalsText
              : UiStrings.onlyTimetable);
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      child: Row(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.x1),
                Row(
                  children: <Widget>[
                    if (live) ...<Widget>[
                      const LiveDot(certainty: Certainty.live),
                      const SizedBox(width: Space.x1),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        style: context.text.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (nextEta.isNotEmpty) ...<Widget>[
            const SizedBox(width: Space.x2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(nextEta, style: context.text.etaLarge),
                Text(UiStrings.nextDeparture, style: context.text.caption),
              ],
            ),
          ],
          if (onToggleFavorite != null) ...<Widget>[
            const SizedBox(width: Space.x1),
            IconBtn(
              icon: Icons.star_border_rounded,
              semanticLabel: UiStrings.favorite,
              onTap: onToggleFavorite,
              size: 40,
              iconSize: 20,
            ),
          ],
        ],
      ),
    );
  }
}

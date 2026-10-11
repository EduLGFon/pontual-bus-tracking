// ArrivalRow: the core row. Left ETA block, centre line badge plus
// destination plus subtitle, right action slot. Height at least 72 dp,
// full-row tap target, and a semantics sentence that reads like speech.
// See docs/ui/UI_SPEC.md 5 and 12.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/util/format_eta.dart';

/// One arrival as a card row.
class ArrivalRow extends StatelessWidget {
  /// Creates a row.
  const ArrivalRow({
    required this.arrival,
    required this.now,
    required this.line,
    this.onTap,
    this.trailing,
    this.large = false,
    this.headline,
    super.key,
  });

  /// Arrival to show.
  final ArrivalVM arrival;

  /// Current instant, São Mateus wall clock held as UTC.
  final DateTime now;

  /// Line the arrival belongs to.
  final LineVM line;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Optional trailing widget, for example a chevron.
  final Widget? trailing;

  /// Uses the hero ETA size.
  final bool large;

  /// Optional headline, defaults to the line name.
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final EtaFormat format = formatEta(arrival, now);
    final bool past =
        arrival.certainty == Certainty.scheduled && arrival.isPast(now);
    final String title = headline ?? line.name;
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: SurfaceCard(
        onTap: onTap,
        semanticLabel: format.a11y,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: large ? 128 : 112,
                child: EtaText(
                  primary: format.primary,
                  secondary: format.secondary,
                  hero: large,
                  semanticLabel: format.a11y,
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        LineBadge.ofLine(line, size: BadgeSize.m),
                        const SizedBox(width: Space.x2),
                        Expanded(
                          child: Text(
                            title,
                            style: context.text.headline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      _subtitle(),
                      style: context.text.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.x2),
                    CertaintyBadge(certainty: arrival.certainty),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: Space.x2),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final List<String> parts = <String>[
      if (line.terminalsText.isNotEmpty) line.terminalsText,
      if (arrival.originLabel != null) arrival.originLabel!,
    ];
    return parts.isEmpty ? '' : parts.join(' · ');
  }
}

// ReliabilityCard: typical delay plus sparkline for the future history
// tab. De-identified aggregates only; empty data renders nothing.
// See docs/ui/UI_SPEC.md 13.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/sparkline.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Card showing the typical delay and its bar history.
class ReliabilityCard extends StatelessWidget {
  /// Creates the card.
  const ReliabilityCard({required this.reliability, super.key});

  /// Aggregates to show. Sample size zero renders nothing.
  final ReliabilityVM reliability;

  @override
  Widget build(BuildContext context) {
    if (reliability.sampleSize <= 0) {
      return const SizedBox.shrink();
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            UiStrings.typicalDelayOf(reliability.typicalDelayMin),
            style: context.text.bodyStrong,
          ),
          const SizedBox(height: Space.x2),
          Sparkline(bars: reliability.bars),
        ],
      ),
    );
  }
}

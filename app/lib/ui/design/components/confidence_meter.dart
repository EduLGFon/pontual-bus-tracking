// ConfidenceMeter: three small bars for prediction confidence
// (low, medium, high). Flagged off with the predictions UI.
// See docs/ui/UI_SPEC.md 5 and 13.1.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Three-bar confidence meter. [level] is 0 low to 2 high, clamped.
class ConfidenceMeter extends StatelessWidget {
  /// Creates the meter.
  const ConfidenceMeter({required this.level, super.key});

  /// Confidence 0 to 2.
  final int level;

  @override
  Widget build(BuildContext context) {
    final int filled = level.clamp(0, 2) + 1;
    final Color on = context.colors.primary;
    final Color off = context.colors.line;
    return Semantics(
      label: UiStrings.confidenceLabel(level.clamp(0, 2)),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 8.0 + i * 5,
              margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
              decoration: BoxDecoration(
                color: i < filled ? on : off,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

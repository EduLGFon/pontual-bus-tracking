// Horizontal-wrap strip of active reports. At most two chips plus an
// overflow chip keep the line sheet calm; the full list lives in a sheet.
// See DECISIONS.md#D82.
import 'package:flutter/material.dart' hide Chip;
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_chip.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Strip of active reports for a line or stop.
class ReportStrip extends StatelessWidget {
  /// Creates the strip.
  const ReportStrip({
    required this.reports,
    required this.onTap,
    required this.onMore,
    this.maxVisible = 2,
    super.key,
  });

  /// Active reports, already sorted by severity.
  final List<ReportVM> reports;

  /// Called when one report is tapped.
  final ValueChanged<ReportVM> onTap;

  /// Called when the overflow chip is tapped.
  final VoidCallback onMore;

  /// Maximum chips shown before the overflow chip.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();
    final List<ReportVM> visible = reports.take(maxVisible).toList();
    final int hidden = reports.length - visible.length;
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: <Widget>[
        for (final ReportVM report in visible)
          ReportChip(report: report, onTap: () => onTap(report)),
        if (hidden > 0)
          Chip(
            label: UiStrings.reportMore(hidden),
            onTap: onMore,
            semanticLabel:
                '${UiStrings.reportMore(hidden)}. '
                '${UiStrings.reportDisclaimer}',
          ),
      ],
    );
  }
}

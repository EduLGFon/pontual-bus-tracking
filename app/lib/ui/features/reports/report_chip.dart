// Report chip: icon, label and age. Incidents warn; waiting stays neutral
// so it never reads as an alert. Colour is always paired with text.
// See DECISIONS.md#D82.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_style.dart';
import 'package:pontual/ui/models/report_vm.dart';

/// One tappable report chip.
class ReportChip extends StatelessWidget {
  /// Creates a report chip.
  const ReportChip({required this.report, this.onTap, super.key});

  /// Report shown by the chip.
  final ReportVM report;

  /// Called on tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = reportInk(context, report.kind);
    final Color fill = reportFill(context, report.kind);
    return Pressable(
      onTap: onTap,
      semanticLabel: reportSemanticLabel(report),
      borderRadius: Radii.pill,
      child: Container(
        constraints: BoxConstraints(
          minHeight: Sizes.chip,
          maxWidth: MediaQuery.sizeOf(context).width - Space.x8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(reportIcon(report.kind), size: 16, color: ink),
            const SizedBox(width: Space.x1),
            Flexible(
              child: Text(
                reportChipLabel(report),
                style: context.text.label.copyWith(color: ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

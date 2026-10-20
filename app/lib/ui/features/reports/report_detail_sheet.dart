// Report detail sheet: what was reported, when, and how many devices
// reported it. No votes in this alpha; only the reporter can retract.
// See DECISIONS.md#D82.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_actions.dart';
import 'package:pontual/ui/features/reports/report_sheet.dart';
import 'package:pontual/ui/features/reports/report_style.dart';
import 'package:pontual/ui/features/reports/reports_providers.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Opens the report detail/list sheet as a root modal.
Future<void> showReportDetailSheet(
  BuildContext context, {
  required List<ReportVM> reports,
  required List<StopPoint> stops,
  Future<void> Function()? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) =>
        ReportDetailSheet(reports: reports, stops: stops, onChanged: onChanged),
  );
}

/// Stop label for a report, using the same picker fallback as the sheet.
String stopLabelFor(String? stopId, List<StopPoint> stops) {
  if (stopId == null) return '';
  for (int i = 0; i < stops.length; i++) {
    if (stops[i].id == stopId) return stopPickerLabel(stops[i], i);
  }
  return UiStrings.reportStopGeneric;
}

/// Modal body listing one or more active reports.
class ReportDetailSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReportDetailSheet({
    required this.reports,
    required this.stops,
    this.onChanged,
    super.key,
  });

  /// Reports to show.
  final List<ReportVM> reports;

  /// Stops used to resolve report targets.
  final List<StopPoint> stops;

  /// Called after a successful retract so the line screen can refresh.
  final Future<void> Function()? onChanged;

  @override
  ConsumerState<ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<ReportDetailSheet> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final Set<String> mine = ref.watch(myReportsProvider);
    return PontualSheet(
      title: UiStrings.reportListTitle,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ReportVM report in widget.reports) ...<Widget>[
            _ReportCard(
              report: report,
              stopLabel: stopLabelFor(report.stop, widget.stops),
              mine: mine.contains(report.key),
              busy: _busy,
              onRetract: () => _retract(report),
            ),
            const SizedBox(height: Space.x3),
          ],
          if (_error != null) ...<Widget>[
            Text(
              _error!,
              style: context.text.body.copyWith(
                color: context.colors.dangerText,
              ),
            ),
            const SizedBox(height: Space.x3),
          ],
          Text(
            UiStrings.reportDisclaimer,
            style: context.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _retract(ReportVM report) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<List<ReportDTO>> result = await sendReport(
      api: ref.read(busApiProvider),
      op: 'retract',
      kind: report.kind,
      lineId: report.lineId,
      stop: report.stop,
    );
    if (!mounted) return;
    if (result is Ok<List<ReportDTO>>) {
      ref.read(myReportsProvider.notifier).remove(report.key);
      ref
          .read(toastControllerProvider.notifier)
          .show(UiStrings.reportRetracted);
      await widget.onChanged?.call();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = reportFailureMessage((result as Err<List<ReportDTO>>).failure);
    });
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.stopLabel,
    required this.mine,
    required this.busy,
    required this.onRetract,
  });

  final ReportVM report;
  final String stopLabel;
  final bool mine;
  final bool busy;
  final VoidCallback onRetract;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      semanticLabel: reportSemanticLabel(report),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                reportIcon(report.kind),
                color: reportInk(context, report.kind),
                size: 22,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  reportLabel(report.kind),
                  style: context.text.bodyStrong,
                ),
              ),
              if (mine) Text(UiStrings.reportMine, style: context.text.caption),
            ],
          ),
          if (stopLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.x1),
            Text(stopLabel, style: context.text.caption),
          ],
          const SizedBox(height: Space.x2),
          for (final String line in reportDetailLines(report))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x1),
              child: Text(line, style: context.text.caption),
            ),
          if (mine) ...<Widget>[
            const SizedBox(height: Space.x2),
            SecondaryButton(
              label: UiStrings.reportRetract,
              compact: true,
              onPressed: busy ? null : onRetract,
            ),
          ],
        ],
      ),
    );
  }
}

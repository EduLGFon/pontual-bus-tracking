// Stop sheet: the waiting check-in plus the stop's active reports. Opened
// by tapping a stop dot on the line map. One tap reports waiting; no
// location permission is requested for reporting.
// See DECISIONS.md#D82.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/adapters/reports_adapter.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_actions.dart';
import 'package:pontual/ui/features/reports/report_detail_sheet.dart';
import 'package:pontual/ui/features/reports/report_sheet.dart';
import 'package:pontual/ui/features/reports/report_strip.dart';
import 'package:pontual/ui/features/reports/reports_providers.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Opens the stop sheet as a root modal.
Future<void> showStopSheet(
  BuildContext context, {
  required StaticLine line,
  required StopPoint stop,
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
        StopSheet(line: line, stop: stop, stops: stops, onChanged: onChanged),
  );
}

/// Modal body of one stop.
class StopSheet extends ConsumerStatefulWidget {
  /// Creates the stop sheet.
  const StopSheet({
    required this.line,
    required this.stop,
    required this.stops,
    this.onChanged,
    super.key,
  });

  /// Line the stop was opened from.
  final StaticLine line;

  /// Selected stop.
  final StopPoint stop;

  /// All stops, for labels and the report sheet.
  final List<StopPoint> stops;

  /// Called after a successful write so the line screen can refresh.
  final Future<void> Function()? onChanged;

  @override
  ConsumerState<StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends ConsumerState<StopSheet> {
  bool _busy = false;
  String? _error;

  String get _waitingKey =>
      reportKeyOf(widget.line.id, ReportKind.waiting, widget.stop.id);

  @override
  Widget build(BuildContext context) {
    final List<ReportVM> reports = ref.watch(reportsVmProvider(widget.line.id));
    final List<ReportVM> stopReports = reports
        .where((ReportVM r) => r.stop == widget.stop.id)
        .toList();
    final bool mine = ref.watch(myReportsProvider).contains(_waitingKey);
    final int index = widget.stops.indexWhere(
      (StopPoint s) => s.id == widget.stop.id,
    );
    final String label = stopPickerLabel(widget.stop, index < 0 ? 0 : index);
    return PontualSheet(
      title: label,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.line.name, style: context.text.caption),
          if (stopReports.isNotEmpty) ...<Widget>[
            const SizedBox(height: Space.x4),
            ReportStrip(
              reports: stopReports,
              onTap: (ReportVM report) => showReportDetailSheet(
                context,
                reports: stopReports,
                stops: widget.stops,
                onChanged: widget.onChanged,
              ),
              onMore: () => showReportDetailSheet(
                context,
                reports: stopReports,
                stops: widget.stops,
                onChanged: widget.onChanged,
              ),
            ),
          ],
          const SizedBox(height: Space.x4),
          PrimaryButton(
            label: mine
                ? UiStrings.reportStillWaiting
                : UiStrings.reportWaitingAction,
            loading: _busy,
            onPressed: _busy ? null : _reportWaiting,
          ),
          if (mine) ...<Widget>[
            const SizedBox(height: Space.x2),
            SecondaryButton(
              label: UiStrings.reportLeaveStop,
              compact: true,
              onPressed: _busy ? null : _retractWaiting,
            ),
          ],
          const SizedBox(height: Space.x2),
          SecondaryButton(
            label: UiStrings.reportAction,
            compact: true,
            onPressed: _busy
                ? null
                : () => showReportSheet(
                    context,
                    lineId: widget.line.id,
                    lineName: widget.line.name,
                    stops: widget.stops,
                    initialStop: widget.stop,
                    onSubmitted: widget.onChanged,
                  ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            Text(
              _error!,
              style: context.text.body.copyWith(
                color: context.colors.dangerText,
              ),
            ),
          ],
          const SizedBox(height: Space.x3),
          Text(
            UiStrings.reportDisclaimer,
            style: context.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _reportWaiting() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<List<ReportDTO>> result = await sendReport(
      api: ref.read(busApiProvider),
      op: 'report',
      kind: ReportKind.waiting,
      lineId: widget.line.id,
      stop: widget.stop.id,
    );
    if (!mounted) return;
    if (result is Ok<List<ReportDTO>>) {
      ref.read(myReportsProvider.notifier).mark(_waitingKey);
      ref.read(toastControllerProvider.notifier).show(UiStrings.reportSent);
      await widget.onChanged?.call();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _error = reportFailureMessage((result as Err<List<ReportDTO>>).failure);
    });
  }

  Future<void> _retractWaiting() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<List<ReportDTO>> result = await sendReport(
      api: ref.read(busApiProvider),
      op: 'retract',
      kind: ReportKind.waiting,
      lineId: widget.line.id,
      stop: widget.stop.id,
    );
    if (!mounted) return;
    if (result is Ok<List<ReportDTO>>) {
      ref.read(myReportsProvider.notifier).remove(_waitingKey);
      ref
          .read(toastControllerProvider.notifier)
          .show(UiStrings.reportRetracted);
      await widget.onChanged?.call();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = false;
      _error = reportFailureMessage((result as Err<List<ReportDTO>>).failure);
    });
  }
}

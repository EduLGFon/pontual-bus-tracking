// Report creation sheet. Four closed kinds, no free text. Waiting and
// blocked require a stop; broken and full are line-level. One report and
// one retract operation only; there are no votes in this alpha.
// See DECISIONS.md#D82.
import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_actions.dart';
import 'package:pontual/ui/features/reports/report_style.dart';
import 'package:pontual/ui/features/reports/reports_providers.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Opens the report sheet as a root modal.
Future<void> showReportSheet(
  BuildContext context, {
  required int lineId,
  required String lineName,
  required List<StopPoint> stops,
  StopPoint? initialStop,
  Future<void> Function()? onSubmitted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (BuildContext context) => ReportSheet(
      lineId: lineId,
      lineName: lineName,
      stops: stops,
      initialStop: initialStop,
      onSubmitted: onSubmitted,
    ),
  );
}

/// Stop label used only inside the picker. Unnamed OSM nodes get a local
/// ordinal; this is a UI locator, never written back to the data.
String stopPickerLabel(StopPoint stop, int index) {
  final String? name = stop.name?.trim();
  if (name != null &&
      name.isNotEmpty &&
      name.toLowerCase() != UiStrings.reportStopGeneric.toLowerCase()) {
    return name;
  }
  return '${UiStrings.reportStopGeneric} ${index + 1}';
}

/// Modal body of the report sheet.
class ReportSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReportSheet({
    required this.lineId,
    required this.lineName,
    required this.stops,
    this.initialStop,
    this.onSubmitted,
    super.key,
  });

  /// Line id the report belongs to.
  final int lineId;

  /// Line name shown as context.
  final String lineName;

  /// Stops available for stop-level kinds.
  final List<StopPoint> stops;

  /// Stop preselected by the stop sheet.
  final StopPoint? initialStop;

  /// Called after a successful send so the line screen can refresh.
  final Future<void> Function()? onSubmitted;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportKind? _kind;
  StopPoint? _stop;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stop = widget.initialStop;
  }

  bool get _canSubmit {
    final ReportKind? kind = _kind;
    if (kind == null || !kind.isKnown || _sending) return false;
    if (kind.requiresStop && _stop == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStops = widget.stops.isNotEmpty;
    return PontualSheet(
      title: UiStrings.reportSheetTitle,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.lineName, style: context.text.caption),
          const SizedBox(height: Space.x4),
          for (final ReportKind kind in const <ReportKind>[
            ReportKind.waiting,
            ReportKind.full,
            ReportKind.broken,
            ReportKind.blocked,
          ]) ...<Widget>[
            _KindOption(
              kind: kind,
              selected: _kind == kind,
              enabled: !kind.requiresStop || hasStops,
              onTap: () => setState(() {
                _kind = kind;
                _error = null;
              }),
            ),
            const SizedBox(height: Space.x2),
          ],
          if (_kind?.requiresStop ?? false) ...<Widget>[
            const SizedBox(height: Space.x3),
            Text(UiStrings.reportChooseStop, style: context.text.label),
            const SizedBox(height: Space.x2),
            if (!hasStops)
              Text(UiStrings.reportNoStops, style: context.text.caption)
            else
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: <Widget>[
                  for (int i = 0; i < widget.stops.length; i++)
                    Chip(
                      label: stopPickerLabel(widget.stops[i], i),
                      selected: _stop?.id == widget.stops[i].id,
                      onTap: () => setState(() {
                        _stop = widget.stops[i];
                        _error = null;
                      }),
                    ),
                ],
              ),
            if (_kind?.requiresStop ?? false) ...<Widget>[
              const SizedBox(height: Space.x1),
              Text(UiStrings.reportChooseStopHint, style: context.text.caption),
            ],
          ],
          const SizedBox(height: Space.x4),
          Text(UiStrings.reportPrivacy, style: context.text.caption),
          if (_error != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            Text(
              _error!,
              style: context.text.body.copyWith(
                color: context.colors.dangerText,
              ),
            ),
          ],
          const SizedBox(height: Space.x4),
          PrimaryButton(
            label: _sending ? UiStrings.reportSending : UiStrings.reportSubmit,
            loading: _sending,
            onPressed: _canSubmit ? _submit : null,
          ),
          const SizedBox(height: Space.x2),
          Text(
            UiStrings.reportDisclaimer,
            style: context.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final ReportKind? kind = _kind;
    final StopPoint? stop = _stop;
    if (kind == null || !_canSubmit) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final Result<List<ReportDTO>> result = await sendReport(
      api: ref.read(busApiProvider),
      op: 'report',
      kind: kind,
      lineId: widget.lineId,
      stop: kind.requiresStop ? stop?.id : null,
    );
    if (!mounted) return;
    if (result is Ok<List<ReportDTO>>) {
      ref
          .read(myReportsProvider.notifier)
          .mark(reportKeyOf(widget.lineId, kind, stop?.id));
      ref.read(toastControllerProvider.notifier).show(UiStrings.reportSent);
      await widget.onSubmitted?.call();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = false;
      _error = reportFailureMessage((result as Err<List<ReportDTO>>).failure);
    });
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ReportKind kind;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = enabled
        ? reportInk(context, kind)
        : context.colors.inkSubtle;
    return Semantics(
      selected: selected,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SurfaceCard(
          selected: selected,
          onTap: enabled ? onTap : null,
          semanticLabel: '${reportLabel(kind)}. ${reportHint(kind)}',
          child: Row(
            children: <Widget>[
              Icon(reportIcon(kind), color: ink, size: 22),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(reportLabel(kind), style: context.text.bodyStrong),
                    const SizedBox(height: Space.x1),
                    Text(reportHint(kind), style: context.text.caption),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

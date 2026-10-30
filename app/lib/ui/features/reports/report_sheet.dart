// Report creation sheet. Four closed kinds, no free text. Waiting and
// blocked use a one-shot location read converted on-device to a ~150 m
// cell; broken and full are line-level. One report and one retract only.
// No votes in this alpha. See DECISIONS.md#D82 and D83.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/data/prefs/report_location_notice.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/features/reports/report_location.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/reports/report_actions.dart';
import 'package:pontual/ui/features/reports/report_location_notice.dart';
import 'package:pontual/ui/features/reports/report_style.dart';
import 'package:pontual/ui/features/reports/reports_providers.dart';
import 'package:pontual/ui/shell/toast_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/ui/util/platform.dart';

/// Opens the report sheet as a root modal.
Future<void> showReportSheet(
  BuildContext context, {
  required int lineId,
  required String lineName,
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
      onSubmitted: onSubmitted,
    ),
  );
}

/// Modal body of the report sheet.
class ReportSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReportSheet({
    required this.lineId,
    required this.lineName,
    this.onSubmitted,
    super.key,
  });

  /// Line id the report belongs to.
  final int lineId;

  /// Line name shown as context.
  final String lineName;

  /// Called after a successful send so the line screen can refresh.
  final Future<void> Function()? onSubmitted;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportKind? _kind;
  bool _sending = false;
  bool _locating = false;
  String? _error;
  ReportLocationFailure? _locationFailure;

  bool get _busy => _sending || _locating;

  bool get _canSubmit {
    final ReportKind? kind = _kind;
    return kind != null && kind.isKnown && !_busy;
  }

  @override
  Widget build(BuildContext context) {
    final bool usesLocation = _kind?.usesLocation ?? false;
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
              onTap: () => setState(() {
                _kind = kind;
                _error = null;
                _locationFailure = null;
              }),
            ),
            const SizedBox(height: Space.x2),
          ],
          if (usesLocation) ...<Widget>[
            const SizedBox(height: Space.x2),
            const _LocationNote(),
          ],
          const SizedBox(height: Space.x4),
          Text(UiStrings.reportPrivacy, style: context.text.caption),
          if (_locationFailure != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            _ReportLocationCard(
              failure: _locationFailure!,
              onRetry: _busy ? null : _submit,
              onOpenSettings: _openSettings,
            ),
          ],
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
            label: _locating
                ? UiStrings.reportLocating
                : _sending
                ? UiStrings.reportSending
                : UiStrings.reportSubmit,
            loading: _busy,
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
    if (kind == null || !_canSubmit) return;
    String? area;
    if (kind.usesLocation) {
      final bool accepted = await _ensureLocationNotice();
      if (!accepted) {
        if (mounted) {
          setState(() => _locationFailure = ReportLocationFailure.denied);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _locating = true;
        _error = null;
        _locationFailure = null;
      });
      final ReportAreaResult result = await ref
          .read(reportLocationServiceProvider)
          .acquire();
      if (!mounted) return;
      if (result is ReportAreaError) {
        setState(() {
          _locating = false;
          _locationFailure = result.reason;
        });
        return;
      }
      area = (result as ReportAreaOk).areaId;
    }
    if (!mounted) return;
    final String optimisticKey = reportKeyOf(widget.lineId, kind, area);
    // Optimistic: mark the report as ours before the round trip, so the
    // strip and the detail sheet reflect the tap immediately. Roll back on
    // failure so a rejected report never looks sent.
    ref.read(myReportsProvider.notifier).mark(optimisticKey);
    setState(() {
      _locating = false;
      _sending = true;
      _error = null;
    });
    final Result<List<ReportDTO>> result = await sendReport(
      api: ref.read(busApiProvider),
      op: 'report',
      kind: kind,
      lineId: widget.lineId,
      area: area,
    );
    if (!mounted) return;
    if (result is Ok<List<ReportDTO>>) {
      ref.read(toastControllerProvider.notifier).show(UiStrings.reportSent);
      await widget.onSubmitted?.call();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    ref.read(myReportsProvider.notifier).remove(optimisticKey);
    setState(() {
      _sending = false;
      _error = reportFailureMessage((result as Err<List<ReportDTO>>).failure);
    });
  }

  Future<bool> _ensureLocationNotice() async {
    const ReportLocationNoticeStore store = ReportLocationNoticeStore();
    try {
      if (await store.accepted()) return true;
    } on Object {
      // A prefs failure must not skip the disclosure.
    }
    if (!mounted) return false;
    final bool accepted = await showReportLocationNotice(context);
    if (accepted) {
      try {
        await store.accept();
      } on Object {
        // The report can proceed; the notice is transparency, not a key.
      }
    }
    return accepted;
  }

  Future<void> _openSettings() async {
    try {
      await ref.read(reportLocationServiceProvider).gateway.openSettings();
    } on Object {
      // The browser or platform may not expose app settings; retry stays.
    }
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ReportKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: SurfaceCard(
        selected: selected,
        onTap: onTap,
        semanticLabel: '${reportLabel(kind)}. ${reportHint(kind)}',
        child: Row(
          children: <Widget>[
            Icon(reportIcon(kind), color: reportInk(context, kind), size: 22),
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
    );
  }
}

class _LocationNote extends StatelessWidget {
  const _LocationNote();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      sunken: true,
      semanticLabel: UiStrings.reportLocationNote,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.location_on_outlined, color: context.colors.inkMuted),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              UiStrings.reportLocationNote,
              style: context.text.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportLocationCard extends StatelessWidget {
  const _ReportLocationCard({
    required this.failure,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final ReportLocationFailure failure;
  final VoidCallback? onRetry;
  final VoidCallback onOpenSettings;

  String get _message {
    return switch (failure) {
      ReportLocationFailure.servicesOff => UiStrings.reportLocationServicesOff,
      ReportLocationFailure.denied => UiStrings.reportLocationDenied,
      ReportLocationFailure.blocked => UiStrings.reportLocationBlocked,
      ReportLocationFailure.timeout => UiStrings.reportLocationTimeout,
      ReportLocationFailure.imprecise => UiStrings.reportLocationImprecise,
      ReportLocationFailure.outsideArea => UiStrings.reportLocationOutsideArea,
      ReportLocationFailure.unknown => UiStrings.reportLocationUnknown,
    };
  }

  bool get _settingsHelp =>
      failure == ReportLocationFailure.blocked ||
      failure == ReportLocationFailure.servicesOff;

  @override
  Widget build(BuildContext context) {
    final bool showSettings = _settingsHelp && !PlatformInfo.isWeb;
    return SurfaceCard(
      semanticLabel: '${UiStrings.reportLocationUnavailable}. $_message',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.location_off_outlined,
                size: 20,
                color: context.colors.warningText,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  UiStrings.reportLocationUnavailable,
                  style: context.text.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          Text(_message, style: context.text.body),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: Space.x2),
            SecondaryButton(
              label: UiStrings.retry,
              compact: true,
              onPressed: onRetry,
            ),
          ],
          if (showSettings) ...<Widget>[
            const SizedBox(height: Space.x2),
            SecondaryButton(
              label: UiStrings.openSettings,
              compact: true,
              onPressed: onOpenSettings,
            ),
          ],
        ],
      ),
    );
  }
}

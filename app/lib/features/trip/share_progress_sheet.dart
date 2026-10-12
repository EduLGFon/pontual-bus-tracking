// Share progress sheet: phased loading for the share-start flow so a
// tap on "Estou no ônibus" never ends in silence. Shows one row per
// phase with pending/active/done/failed states, a GPS countdown, and
// an expandable technical details block (error codes and counts only,
// never coordinates, tokens, or device ids). Widgets hold no logic;
// the ShareProgressTracker owns state. See PLAN.md S06.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/strings/ui_strings.dart';
import 'package:pontual/domain/trip/share_phases.dart';
import 'package:pontual/features/trip/share_progress_tracker.dart';

/// Phased progress sheet for one share attempt.
class ShareProgressSheet extends StatefulWidget {
  /// Creates a sheet driven by [tracker].
  const ShareProgressSheet({
    required this.tracker,
    required this.lineLabel,
    required this.onCancel,
    required this.onRetry,
    required this.onClose,
    super.key,
  });

  /// Progress state, owned by the share flow.
  final ShareProgressTracker tracker;

  /// Human line label for the title.
  final String lineLabel;

  /// Called when the user taps Cancelar.
  final void Function() onCancel;

  /// Called when the user taps Tentar de novo.
  final void Function() onRetry;

  /// Called when the user taps Fechar after a failure.
  final void Function() onClose;

  @override
  State<ShareProgressSheet> createState() => _ShareProgressSheetState();
}

class _ShareProgressSheetState extends State<ShareProgressSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One 1 s ticker for the GPS countdown only; cancelled in dispose.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tracker,
      builder: (BuildContext context, _) {
        final ShareProgressTracker tracker = widget.tracker;
        final bool failed = tracker.hasFailure;
        final String? message = failed ? _messageFor(context) : null;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  liveRegion: true,
                  label: failed
                      ? 'Falha ao iniciar viagem'
                      : 'Iniciando viagem',
                  child: Text(
                    UiStrings.shareProgressTitle,
                    style: context.text.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.lineLabel, style: context.text.body),
                const SizedBox(height: 16),
                for (final SharePhase phase in sharePhaseOrder)
                  _phaseRow(context, tracker, phase),
                if (message != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(message, style: context.text.body),
                ],
                const SizedBox(height: 8),
                _details(context, tracker),
                const SizedBox(height: 16),
                if (!failed)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text(UiStrings.shareProgressCancel),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text(UiStrings.shareProgressClose),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: widget.onRetry,
                        child: const Text(UiStrings.shareProgressRetry),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _phaseRow(
    BuildContext context,
    ShareProgressTracker tracker,
    SharePhase phase,
  ) {
    final SharePhaseStatus status =
        tracker.statuses[phase] ?? SharePhaseStatus.pending;
    final Widget icon;
    switch (status) {
      case SharePhaseStatus.active:
        icon = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SharePhaseStatus.done:
        icon = Icon(Icons.check_circle, color: context.colors.live, size: 20);
      case SharePhaseStatus.failed:
        icon = Icon(Icons.error, color: context.colors.danger, size: 20);
      case SharePhaseStatus.pending:
        icon = Icon(
          Icons.circle_outlined,
          color: context.colors.inkSubtle,
          size: 20,
        );
    }
    final String label = _labelFor(phase);
    String? sub;
    if (phase == SharePhase.gps && status == SharePhaseStatus.active) {
      final int? left = tracker.gpsSecsLeft;
      sub = left == null
          ? UiStrings.shareGpsTip
          : '${left}s - ${UiStrings.shareGpsTip}';
    }
    return Semantics(
      label: '$label: ${status.name}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: context.text.body),
                  if (sub != null) Text(sub, style: context.text.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(SharePhase phase) {
    switch (phase) {
      case SharePhase.services:
        return UiStrings.sharePhaseServices;
      case SharePhase.config:
        return UiStrings.sharePhaseConfig;
      case SharePhase.consent:
        return UiStrings.sharePhaseConsent;
      case SharePhase.permission:
        return UiStrings.sharePhasePermission;
      case SharePhase.register:
        return UiStrings.sharePhaseRegister;
      case SharePhase.gps:
        return UiStrings.sharePhaseGps;
      case SharePhase.start:
        return UiStrings.sharePhaseStart;
    }
  }

  String? _messageFor(BuildContext context) {
    final ShareProgressTracker tracker = widget.tracker;
    final SharePhase failed = sharePhaseOrder.firstWhere(
      (SharePhase p) => tracker.statuses[p] == SharePhaseStatus.failed,
      orElse: () => SharePhase.start,
    );
    switch (failed) {
      case SharePhase.gps:
        return UiStrings.shareNoGps;
      case SharePhase.register:
      case SharePhase.start:
      case SharePhase.config:
        if (tracker.errorCode == 'offline') {
          return UiStrings.shareNoConnection;
        }
        if (tracker.errorCode == 'area') {
          return UiStrings.shareOutsideArea;
        }
        if (tracker.errorCode == 'capacity') {
          return UiStrings.capacity;
        }
        if (tracker.errorCode == 'quota' ||
            tracker.errorCode == 'rate' ||
            tracker.errorCode == 'maint') {
          return UiStrings.shareBusy;
        }
        return UiStrings.shareStartFailed;
      case SharePhase.services:
      case SharePhase.consent:
      case SharePhase.permission:
        return UiStrings.shareStartFailed;
    }
  }

  Widget _details(BuildContext context, ShareProgressTracker tracker) {
    // Technical details for field testing: phase ids, error codes, and
    // counts only. Never coordinates, tokens, or device ids.
    final StringBuffer rows = StringBuffer()
      ..writeln('fase: ${_currentPhaseId(tracker)}')
      ..writeln('erro: ${tracker.errorCode ?? '-'}')
      ..writeln('tentativa: ${tracker.attempt}')
      ..writeln('consent: v${tracker.consentVersion}')
      ..writeln('linha: ${tracker.lineId}')
      ..writeln('host: ${tracker.host}');
    final int? left = tracker.gpsSecsLeft;
    if (left != null) {
      rows.writeln('gps: aguardando (${left}s)');
    }
    return ExpansionTile(
      iconColor: context.colors.inkMuted,
      collapsedIconColor: context.colors.inkMuted,
      textColor: context.colors.ink,
      collapsedTextColor: context.colors.ink,
      title: Text(
        UiStrings.shareProgressDetails,
        style: context.text.bodyStrong,
      ),
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            rows.toString().trim(),
            style: context.text.caption,
          ),
        ),
      ],
    );
  }

  String _currentPhaseId(ShareProgressTracker tracker) {
    for (final SharePhase phase in sharePhaseOrder) {
      if (tracker.statuses[phase] == SharePhaseStatus.active) {
        return phase.name;
      }
    }
    for (final SharePhase phase in sharePhaseOrder) {
      if (tracker.statuses[phase] == SharePhaseStatus.failed) {
        return phase.name;
      }
    }
    if (tracker.allDone) {
      return 'ok';
    }
    return '-';
  }
}

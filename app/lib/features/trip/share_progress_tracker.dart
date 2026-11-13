// Progress tracker for the share-start flow. Single source of truth
// behind ShareProgressSheet: share_flow drives services/config, and
// TripController reports consent/permission/register/gps/start through
// onPhase. Holds no PII: error codes and counts only, never coordinates,
// tokens, or device ids. See ARCHITECTURE.md S06.
import 'package:flutter/foundation.dart';
import 'package:pontual/domain/trip/share_phases.dart';

/// Tracks the visible progress of one share attempt.
class ShareProgressTracker extends ChangeNotifier {
  /// Creates a tracker for [lineId] with the current [consentVersion].
  ShareProgressTracker({
    required this.lineId,
    required this.consentVersion,
    required this.host,
    required this.nowMs,
    this.gpsTimeoutS = 60,
  }) {
    for (final SharePhase phase in sharePhaseOrder) {
      _statuses[phase] = SharePhaseStatus.pending;
    }
  }

  /// Line being shared.
  final int lineId;

  /// Consent text version for this attempt.
  final int consentVersion;

  /// API host shown in the details (host only, no secrets).
  final String host;

  /// Milliseconds clock, injectable for tests.
  final int Function() nowMs;

  /// First-fix wait window in seconds.
  final int gpsTimeoutS;

  final Map<SharePhase, SharePhaseStatus> _statuses =
      <SharePhase, SharePhaseStatus>{};

  /// Current status per phase.
  Map<SharePhase, SharePhaseStatus> get statuses =>
      Map<SharePhase, SharePhaseStatus>.unmodifiable(_statuses);

  /// Last error code from the failing phase, if any.
  String? get errorCode => _errorCode;
  String? _errorCode;

  /// How many share attempts this tracker has seen.
  int get attempt => _attempt;
  int _attempt = 1;

  /// Deadline of the GPS wait in ms, or null outside the GPS phase.
  int? get gpsDeadlineMs => _gpsDeadlineMs;
  int? _gpsDeadlineMs;

  /// True after the user taps Cancelar.
  bool get cancelled => _cancelled;
  bool _cancelled = false;

  /// True when any phase failed.
  bool get hasFailure => _statuses.values.any(
    (SharePhaseStatus s) => s == SharePhaseStatus.failed,
  );

  /// True when every phase is done.
  bool get allDone => _statuses.values.every(
    (SharePhaseStatus s) => s == SharePhaseStatus.done,
  );

  /// Seconds left in the GPS wait, or null outside the GPS phase.
  int? get gpsSecsLeft {
    final int? deadline = _gpsDeadlineMs;
    if (deadline == null ||
        _statuses[SharePhase.gps] != SharePhaseStatus.active) {
      return null;
    }
    final int left = (deadline - nowMs()) ~/ 1000;
    return left < 0 ? 0 : left;
  }

  /// Reports a phase transition. Notifies listeners.
  void report(SharePhase phase, SharePhaseStatus status, {String? errorCode}) {
    _statuses[phase] = status;
    if (status == SharePhaseStatus.failed && errorCode != null) {
      _errorCode = errorCode;
    }
    if (status == SharePhaseStatus.active && phase == SharePhase.gps) {
      _gpsDeadlineMs = nowMs() + gpsTimeoutS * 1000;
    }
    if (status != SharePhaseStatus.active && phase == SharePhase.gps) {
      _gpsDeadlineMs = null;
    }
    notifyListeners();
  }

  /// Marks a new attempt after Tentar de novo. Keeps line and host.
  void nextAttempt() {
    _attempt += 1;
    _errorCode = null;
    _gpsDeadlineMs = null;
    for (final SharePhase phase in sharePhaseOrder) {
      _statuses[phase] = SharePhaseStatus.pending;
    }
    notifyListeners();
  }

  /// Records user cancellation. The controller polls [cancelled].
  void cancel() {
    _cancelled = true;
    notifyListeners();
  }
}

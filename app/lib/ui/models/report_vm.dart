// Report view-model. Ages are already advanced to now by the repository;
// the UI never uses the device wall clock for freshness.
// See DECISIONS.md#D82.
import 'package:flutter/foundation.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/domain/reporting/report_kind.dart';

/// One active passenger report shown on a line or stop.
@immutable
class ReportVM {
  /// Creates a report view-model.
  const ReportVM({
    required this.lineId,
    required this.kind,
    required this.stop,
    required this.count,
    required this.createdAgeS,
    required this.updatedAgeS,
    required this.expiresInS,
  });

  /// Line the report belongs to.
  final int lineId;

  /// Report kind.
  final ReportKind kind;

  /// Static stop id for stop-level kinds, null for line-level incidents.
  final String? stop;

  /// Distinct devices that reported this target.
  final int count;

  /// Seconds since the first report.
  final int createdAgeS;

  /// Seconds since the latest report from any device.
  final int updatedAgeS;

  /// Seconds until expiry.
  final int expiresInS;

  /// Stable local key for "mine" tracking and retraction.
  String get key => '$lineId:${kind.wire}:${stop ?? '-'}';

  /// True when the TTL has run out.
  bool get isExpired => expiresInS <= 0;

  /// True for the waiting family.
  bool get isPresence => kind.isPresence;

  /// Maps a repository report, stamping the line id.
  factory ReportVM.fromClient(int lineId, ClientReport report) {
    return ReportVM(
      lineId: lineId,
      kind: report.kind,
      stop: report.stop,
      count: report.count,
      createdAgeS: report.createdAgeS,
      updatedAgeS: report.updatedAgeS,
      expiresInS: report.expiresInS,
    );
  }
}

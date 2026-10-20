// Report view-model. Ages are already advanced to now by the repository;
// the UI never uses the device wall clock for freshness.
// See DECISIONS.md#D82/D83.
import 'package:flutter/foundation.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/domain/reporting/report_kind.dart';

/// One active passenger report shown on a line.
@immutable
class ReportVM {
  /// Creates a report view-model.
  const ReportVM({
    required this.lineId,
    required this.kind,
    required this.area,
    required this.count,
    required this.createdAgeS,
    required this.updatedAgeS,
    required this.expiresInS,
    this.distanceM,
  });

  /// Line the report belongs to.
  final int lineId;

  /// Report kind.
  final ReportKind kind;

  /// Coarse ~150 m cell for area-level kinds, null for line-level ones.
  final String? area;

  /// Distinct devices that reported this target.
  final int count;

  /// Seconds since the first report.
  final int createdAgeS;

  /// Seconds since the latest report from any device.
  final int updatedAgeS;

  /// Seconds until expiry.
  final int expiresInS;

  /// Distance from the viewer to the cell center, null when unknown.
  final double? distanceM;

  /// Stable local key for "mine" tracking and retraction.
  String get key => '$lineId:${kind.wire}:${area ?? '-'}';

  /// True when the TTL has run out.
  bool get isExpired => expiresInS <= 0;

  /// True for the waiting family.
  bool get isPresence => kind.isPresence;

  /// Maps a repository report, stamping the line id.
  factory ReportVM.fromClient(
    int lineId,
    ClientReport report, {
    double? distanceM,
  }) {
    return ReportVM(
      lineId: lineId,
      kind: report.kind,
      area: report.area,
      count: report.count,
      createdAgeS: report.createdAgeS,
      updatedAgeS: report.updatedAgeS,
      expiresInS: report.expiresInS,
      distanceM: distanceM,
    );
  }
}

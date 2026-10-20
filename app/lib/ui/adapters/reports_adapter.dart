// Reports for one line, shaped for the UI. The repository owns the socket
// and the monotonic ages; this adapter filters expired rows and sorts by
// severity. Auto-disposed with the line screen.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/domain/reporting/report_area.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/ui/models/report_vm.dart';

/// Severity order: blocked, broken, full, waiting, unknown last.
int reportSeverity(ReportKind kind) {
  return switch (kind) {
    ReportKind.blocked => 0,
    ReportKind.broken => 1,
    ReportKind.full => 2,
    ReportKind.waiting => 3,
    ReportKind.unknown => 4,
  };
}

/// Active reports of one line. Rebuilds with the line's 5 s tick so a
/// stream update or a post-write refresh appears promptly; the rendered
/// age labels themselves are minute-granular.
final reportsVmProvider = Provider.autoDispose.family<List<ReportVM>, int>((
  Ref ref,
  int lineId,
) {
  ref.watch(vehicleTickProvider);
  final VehicleRepository repo = ref.watch(vehicleRepoProvider(lineId));
  final LatLng? viewer = ref.watch(viewerLocationProvider).value;
  final List<ReportVM> out = repo.reports
      .where((ClientReport r) => r.expiresInS > 0)
      .map((ClientReport r) {
        final double? distanceM = viewer != null && r.area != null
            ? reportAreaDistanceM(r.area!, viewer.latitude, viewer.longitude)
            : null;
        return ReportVM.fromClient(lineId, r, distanceM: distanceM);
      })
      .toList();
  out.sort((ReportVM a, ReportVM b) {
    final int byKind = reportSeverity(a.kind) - reportSeverity(b.kind);
    if (byKind != 0) return byKind;
    final double? aDistance = a.distanceM;
    final double? bDistance = b.distanceM;
    if (aDistance != null && bDistance != null) {
      final int byDistance = aDistance.compareTo(bDistance);
      if (byDistance != 0) return byDistance;
    }
    return a.updatedAgeS.compareTo(b.updatedAgeS);
  });
  return out;
});

// Report submission helpers. The device token is created on demand, the
// server owns timestamps and TTLs, and failures map to short pt-BR copy.
// See DECISIONS.md#D82/D83.
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/data/api/bus_api.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Ensures a token and sends one report/retract operation.
Future<Result<List<ReportDTO>>> sendReport({
  required BusApi api,
  required String op,
  required ReportKind kind,
  required int lineId,
  String? area,
}) async {
  final Result<String> token = await api.ensureRegistered();
  if (token is Err<String>) return Err<List<ReportDTO>>(token.failure);
  return api.postReport(
    (token as Ok<String>).value,
    op: op,
    kind: kind,
    lineId: lineId,
    area: area,
  );
}

/// User-facing message for a report failure. Never echoes internals.
String reportFailureMessage(AppFailure failure) {
  if (failure is NetworkFailure) return UiStrings.reportOffline;
  if (failure is ServerFailure) {
    return switch (failure.code) {
      'rate' => UiStrings.reportRate,
      'quota' => UiStrings.reportQuota,
      'maint' || 'capacity' => UiStrings.reportDisabled,
      _ => UiStrings.genericError,
    };
  }
  return UiStrings.genericError;
}

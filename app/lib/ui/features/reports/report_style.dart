// Copy, icons and colour roles for passenger reports. Colour is never the
// only signal: every surface also carries an icon and a pt-BR label.
// See DECISIONS.md#D82/D83 and docs/ui/UI_SPEC.md 4.
import 'package:flutter/material.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Short label of a report kind.
String reportLabel(ReportKind kind) {
  return switch (kind) {
    ReportKind.waiting => UiStrings.reportWaiting,
    ReportKind.full => UiStrings.reportFull,
    ReportKind.broken => UiStrings.reportBroken,
    ReportKind.blocked => UiStrings.reportBlocked,
    ReportKind.unknown => UiStrings.reportUnknown,
  };
}

/// One-line explanation shown in the report sheet.
String reportHint(ReportKind kind) {
  return switch (kind) {
    ReportKind.waiting => UiStrings.reportWaitingHint,
    ReportKind.full => UiStrings.reportFullHint,
    ReportKind.broken => UiStrings.reportBrokenHint,
    ReportKind.blocked => UiStrings.reportBlockedHint,
    ReportKind.unknown => UiStrings.reportDisclaimer,
  };
}

/// Icon for a report kind. Waiting is neutral; incidents warn.
IconData reportIcon(ReportKind kind) {
  return switch (kind) {
    ReportKind.waiting => Icons.schedule_rounded,
    ReportKind.full => Icons.directions_bus_filled_rounded,
    ReportKind.broken => Icons.build_circle_outlined,
    ReportKind.blocked => Icons.block_rounded,
    ReportKind.unknown => Icons.flag_outlined,
  };
}

/// Foreground role for a report chip.
Color reportInk(BuildContext context, ReportKind kind) {
  if (kind == ReportKind.waiting || kind == ReportKind.unknown) {
    return context.colors.inkMuted;
  }
  return context.colors.warningText;
}

/// Fill role for a report chip.
Color reportFill(BuildContext context, ReportKind kind) {
  if (kind == ReportKind.waiting || kind == ReportKind.unknown) {
    return context.colors.surfaceSunken;
  }
  return context.colors.warning.withValues(alpha: 0.12);
}

/// Relative age from seconds. Coarse on purpose; the UI ticks once a minute.
String reportAgeLabel(int seconds) {
  if (seconds < 60) return UiStrings.reportAgeNow;
  if (seconds < 3600) return UiStrings.reportAgeMinutes(seconds ~/ 60);
  return UiStrings.reportAgeHours(seconds ~/ 3600);
}

/// Count sentence for the detail sheet.
String reportCountLabel(ReportVM report) {
  if (report.isPresence) {
    return report.count <= 1
        ? UiStrings.reportSomeoneWaiting
        : UiStrings.reportPeopleWaiting(report.count);
  }
  return report.count <= 1
      ? UiStrings.reportOneReport
      : UiStrings.reportPeopleReported(report.count);
}

/// Compact chip label.
String reportChipLabel(ReportVM report) {
  final String age = reportAgeLabel(report.updatedAgeS);
  if (report.isPresence) {
    final String count = report.count <= 1
        ? UiStrings.reportChipSomeone
        : UiStrings.reportChipWaiting(report.count);
    return UiStrings.reportChipIncident(count, age);
  }
  return UiStrings.reportChipIncident(reportLabel(report.kind), age);
}

/// Human distance to the report area. Rounded to 50 m because the cell is
/// approximate; never presented as a precise position.
int roundedReportDistanceM(double distanceM) {
  final int rounded = (distanceM / 50).round() * 50;
  return rounded < 50 ? 50 : rounded;
}

/// Area line for the detail sheet, null for line-level reports.
String? reportAreaLine(ReportVM report) {
  if (report.area == null) return null;
  final double? distance = report.distanceM;
  if (distance == null) return UiStrings.reportAreaApprox;
  return UiStrings.reportAreaNear(roundedReportDistanceM(distance));
}

/// Screen-reader sentence for a report chip or row.
String reportSemanticLabel(ReportVM report) {
  final String age = reportAgeLabel(report.updatedAgeS);
  final String count = reportCountLabel(report);
  final String? area = reportAreaLine(report);
  return '${reportLabel(report.kind)}, $age. $count.'
      '${area == null ? '' : ' $area.'} ${UiStrings.reportDisclaimer}';
}

/// Detail lines: first report, last update, count and coarse area.
List<String> reportDetailLines(ReportVM report) {
  return <String>[
    UiStrings.reportReportedAgo(reportAgeLabel(report.createdAgeS)),
    UiStrings.reportUpdatedAgo(reportAgeLabel(report.updatedAgeS)),
    reportCountLabel(report),
    if (reportAreaLine(report) case final String area) area,
  ];
}

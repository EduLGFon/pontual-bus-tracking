// Typed DTOs for the Pontual API. Field names match the server contract
// in PLAN.md 6.5. No trip or session ids exist anywhere.
import 'package:pontual/core/errors/failures.dart';
import 'package:pontual/domain/reporting/report_kind.dart';

/// Server instruction for a reporter: role plus next interval in seconds.
class TripInstruction {
  /// Creates an instruction.
  const TripInstruction({
    required this.role,
    required this.intervalS,
    this.end,
  });

  /// Leader, follower, or waiting.
  final String role;

  /// Seconds until the next ping.
  final int intervalS;

  /// Present when the trip ended: idle, timeout, or abuse.
  final String? end;
}

/// Public vehicle snapshot for one line.
class VehiclesSnapshot {
  /// Creates a snapshot.
  const VehiclesSnapshot({
    required this.epochS,
    required this.vehicles,
    this.reports = const <ReportDTO>[],
  });

  /// Snapshot time as epoch seconds.
  final int epochS;

  /// Rows of [id, lat, lng, heading, kmh, n, ageS, paceKmh?].
  /// The 8th field is additive (D30); 7-field rows still parse.
  final List<List<num?>> vehicles;

  /// Active passenger reports for this line (D82). Additive; old
  /// servers omit the field and this stays empty.
  final List<ReportDTO> reports;
}

/// One active passenger report from the line snapshot. No coordinates,
/// no device or reporter id, no free text.
class ReportDTO {
  /// Creates a report DTO.
  const ReportDTO({
    required this.kind,
    required this.stop,
    required this.count,
    required this.createdAgeS,
    required this.updatedAgeS,
    required this.expiresInS,
  });

  /// Report kind, [ReportKind.unknown] when this app is older.
  final ReportKind kind;

  /// Static stop id for waiting/blocked, null for line-level incidents.
  final String? stop;

  /// Distinct devices that reported this target. One is a single source.
  final int count;

  /// Seconds since the first report.
  final int createdAgeS;

  /// Seconds since the last report from any device.
  final int updatedAgeS;

  /// Seconds until the report expires.
  final int expiresInS;

  /// Parses one item. Returns null on a malformed shape instead of
  /// breaking the whole snapshot.
  static ReportDTO? fromJson(Object? raw) {
    if (raw is! Map<dynamic, dynamic>) return null;
    final Map<String, dynamic> json = raw.cast<String, dynamic>();
    final Object? kind = json['kind'];
    final Object? stop = json['stop'];
    final Object? count = json['count'];
    final Object? created = json['created_age_s'];
    final Object? updated = json['updated_age_s'];
    final Object? expires = json['expires_in_s'];
    if (kind is! String ||
        (stop != null && stop is! String) ||
        count is! num ||
        created is! num ||
        updated is! num ||
        expires is! num) {
      return null;
    }
    return ReportDTO(
      kind: ReportKind.fromWire(kind),
      stop: stop as String?,
      count: count.toInt(),
      createdAgeS: created.toInt(),
      updatedAgeS: updated.toInt(),
      expiresInS: expires.toInt(),
    );
  }
}

/// Parses the optional `r` array, dropping malformed items. An unknown
/// kind is kept with [ReportKind.unknown] and rendered neutrally.
List<ReportDTO> parseReports(Object? raw) {
  if (raw is! List<dynamic>) return const <ReportDTO>[];
  final List<ReportDTO> out = <ReportDTO>[];
  for (final Object? item in raw) {
    final ReportDTO? parsed = ReportDTO.fromJson(item);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

/// Anonymous recent arrivals for one line (D30). Timestamps only,
/// no positions and no ids. Timetables stay the fallback.
class ArrivalsPayload {
  /// Creates an arrivals payload.
  const ArrivalsPayload({
    required this.epochS,
    required this.lineId,
    required this.passages,
    required this.headwayMin,
    required this.sampleSize,
  });

  /// Response time as epoch seconds.
  final int epochS;

  /// Line id the payload refers to.
  final int lineId;

  /// Recent sighting times as epoch seconds, oldest first.
  final List<int> passages;

  /// Median headway in minutes, null with fewer than 2 sightings.
  final double? headwayMin;

  /// How many sightings back the values. Zero hides history cards.
  final int sampleSize;

  /// Parses a payload. Wrong types fall back to empty (hidden).
  factory ArrivalsPayload.fromJson(Map<String, dynamic> json) {
    final Object? rawPassages = json['passages'];
    return ArrivalsPayload(
      epochS: json['t'] is int ? json['t'] as int : 0,
      lineId: json['line'] is int ? json['line'] as int : 0,
      passages: rawPassages is List
          ? rawPassages.whereType<num>().map((num n) => n.toInt()).toList()
          : const <int>[],
      headwayMin: json['headwayMin'] is num
          ? (json['headwayMin'] as num).toDouble()
          : null,
      sampleSize: json['sampleSize'] is int ? json['sampleSize'] as int : 0,
    );
  }
}

/// Live-lines payload: pairs of line id and capped vehicle count.
class LiveLines {
  /// Creates a live-lines payload.
  const LiveLines(this.rows);

  /// Rows of [lineId, count].
  final List<List<int>> rows;
}

/// Maps an HTTP error response to a typed failure.
ServerFailure mapError(int status, String? code) {
  return ServerFailure('request failed', code ?? 'unknown');
}

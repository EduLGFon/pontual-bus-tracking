// Typed DTOs for the Pontual API. Field names match the server contract
// in PLAN.md 6.5. No trip or session ids exist anywhere.
import 'package:pontual/core/errors/failures.dart';

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
  const VehiclesSnapshot({required this.epochS, required this.vehicles});

  /// Snapshot time as epoch seconds.
  final int epochS;

  /// Rows of [id, lat, lng, heading, kmh, n, ageS, paceKmh?].
  /// The 8th field is additive (D30); 7-field rows still parse.
  final List<List<num?>> vehicles;
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

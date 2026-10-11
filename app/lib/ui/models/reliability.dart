// Reliability aggregates for the future history tab. De-identified only:
// typical delay plus a small bar series, never per-trip tracks.
// See docs/ui/UI_SPEC.md 13.
import 'package:flutter/foundation.dart';

/// Aggregated reliability of a line and hour. Flagged off until the
/// backend serves de-identified aggregates.
@immutable
class ReliabilityVM {
  /// Creates the aggregates.
  const ReliabilityVM({
    required this.typicalDelayMin,
    required this.sampleSize,
    this.bars = const <double>[],
  });

  /// Typical delay in minutes for this line and hour.
  final int typicalDelayMin;

  /// How many de-identified samples back the value. Zero hides the card.
  final int sampleSize;

  /// Bar heights 0 to 1 for the sparkline, oldest first.
  final List<double> bars;

  /// Reads aggregates. Wrong types fall back to empty (hidden).
  factory ReliabilityVM.fromJson(Map<String, dynamic> json) {
    return ReliabilityVM(
      typicalDelayMin: json['typical_delay_min'] is int
          ? json['typical_delay_min'] as int
          : 0,
      sampleSize: json['sample_size'] is int ? json['sample_size'] as int : 0,
      bars: json['bars'] is List
          ? (json['bars'] as List)
                .whereType<num>()
                .map((num v) => v.toDouble().clamp(0.0, 1.0))
                .toList()
          : const <double>[],
    );
  }

  /// Writes aggregates.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'typical_delay_min': typicalDelayMin,
      'sample_size': sampleSize,
      'bars': bars,
    };
  }
}

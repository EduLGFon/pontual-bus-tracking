// Reliability aggregates for the future history tab. De-identified only:
// typical delay plus a small bar series, never per-trip tracks.
// See docs/ui/UI_SPEC.md 13.
//
// D30: built from the anonymous arrivals payload (timestamps only) plus
// the static timetable headway. Null and empty mean hidden.
import 'dart:math' as math;

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

/// Builds reliability from anonymous sighting data: [passages] are
/// epoch seconds oldest first, [headwayMin] their median gap, and
/// [scheduledHeadwayMin] the timetable median gap. Returns null when
/// there is nothing honest to show. Bars are the last 8 headways
/// normalized 0 to 1; the typical delay is actual minus scheduled,
/// floored at zero.
ReliabilityVM? reliabilityOf({
  required List<int> passages,
  required double? headwayMin,
  required double? scheduledHeadwayMin,
}) {
  if (passages.length < 2 ||
      headwayMin == null ||
      scheduledHeadwayMin == null ||
      scheduledHeadwayMin <= 0) {
    return null;
  }
  final int delay = math.max(0, (headwayMin - scheduledHeadwayMin).round());
  final List<double> gaps = <double>[];
  for (int i = 1; i < passages.length; i++) {
    gaps.add((passages[i] - passages[i - 1]) / 60);
  }
  final List<double> recent = gaps.length <= 8
      ? gaps
      : gaps.sublist(gaps.length - 8);
  double peak = 1;
  for (final double g in recent) {
    if (g > peak) {
      peak = g;
    }
  }
  return ReliabilityVM(
    typicalDelayMin: delay,
    sampleSize: passages.length,
    bars: <double>[for (final double g in recent) (g / peak).clamp(0.0, 1.0)],
  );
}

/// Median gap in minutes of sorted HH:MM times. Null with fewer
/// than 2 times. Pure helper for the scheduled headway.
double? scheduledHeadwayOf(List<String> times) {
  if (times.length < 2) {
    return null;
  }
  final List<int> minutes = <int>[for (final String t in times) _minutesOf(t)]
    ..sort();
  final List<int> gaps = <int>[
    for (int i = 1; i < minutes.length; i++) minutes[i] - minutes[i - 1],
  ]..sort();
  final int mid = gaps.length ~/ 2;
  final double median = gaps.length.isOdd
      ? gaps[mid].toDouble()
      : (gaps[mid - 1] + gaps[mid]) / 2;
  return median;
}

int _minutesOf(String hhmm) {
  final List<String> parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

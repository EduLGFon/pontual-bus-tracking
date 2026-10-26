// ETA estimate from the learning subsystem. Pure Dart, no Flutter imports.

/// A single ETA estimate for a vehicle to a stop.
class EtaItem {
  /// Creates an ETA item.
  const EtaItem({
    required this.vehicleId,
    required this.etaS,
    required this.confidence,
    required this.sampleCount,
  });

  /// Vehicle id.
  final int vehicleId;

  /// Estimated time of arrival in seconds.
  final int etaS;

  /// Confidence level (high, medium, low).
  final String confidence;

  /// Number of samples backing the estimate.
  final int sampleCount;

  /// Parses an ETA item from JSON.
  factory EtaItem.fromJson(Map<String, dynamic> json) {
    return EtaItem(
      vehicleId: (json['vehicle'] as num).toInt(),
      etaS: (json['eta_s'] as num?)?.toInt() ?? 0,
      confidence: json['conf'] as String? ?? 'low',
      sampleCount: (json['n'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of fetching ETA for a stop.
class EtaResult {
  /// Creates an ETA result.
  const EtaResult({
    required this.stopId,
    required this.nowS,
    required this.items,
    this.nextScheduledS,
  });

  /// Stop id.
  final String stopId;

  /// Server now in seconds.
  final int nowS;

  /// ETA items per vehicle.
  final List<EtaItem> items;

  /// Next scheduled arrival in seconds, if any.
  final int? nextScheduledS;

  /// Parses an ETA result from JSON.
  factory EtaResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['items'] as List<dynamic>?) ?? <dynamic>[];
    return EtaResult(
      stopId: json['stop'] as String,
      nowS: (json['now'] as num?)?.toInt() ?? 0,
      items: raw
          .map(
            (dynamic e) => EtaItem.fromJson(
              (e as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      nextScheduledS: (json['next_scheduled_s'] as num?)?.toInt(),
    );
  }
}
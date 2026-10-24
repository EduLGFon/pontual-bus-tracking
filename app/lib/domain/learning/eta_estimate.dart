// ETA estimate from the learning subsystem. Pure Dart, no Flutter imports.
class EtaItem {
  const EtaItem({
    required this.vehicleId,
    required this.etaS,
    required this.confidence,
    required this.sampleCount,
  });

  final int vehicleId;
  final int etaS;
  final String confidence;
  final int sampleCount;

  factory EtaItem.fromJson(Map<String, dynamic> json) {
    return EtaItem(
      vehicleId: (json['vehicle'] as num).toInt(),
      etaS: (json['eta_s'] as num?)?.toInt() ?? 0,
      confidence: json['conf'] as String? ?? 'low',
      sampleCount: (json['n'] as num?)?.toInt() ?? 0,
    );
  }
}

class EtaResult {
  const EtaResult({
    required this.stopId,
    required this.nowS,
    required this.items,
    this.nextScheduledS,
  });

  final String stopId;
  final int nowS;
  final List<EtaItem> items;
  final int? nextScheduledS;

  factory EtaResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['items'] as List<dynamic>?) ?? <dynamic>[];
    return EtaResult(
      stopId: json['stop'] as String,
      nowS: (json['now'] as num?)?.toInt() ?? 0,
      items: raw
          .map((dynamic e) =>
              EtaItem.fromJson((e as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(growable: false),
      nextScheduledS: (json['next_scheduled_s'] as num?)?.toInt(),
    );
  }
}
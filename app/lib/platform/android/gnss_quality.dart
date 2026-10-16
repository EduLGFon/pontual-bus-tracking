// GNSS signal quality from the Android native side: satellites in view
// and in fix plus mean carrier-to-noise density. No coordinates cross
// the channel, only signal quality, so this carries no location data
// and is safe to sample during a trip for quality tiers and field
// diagnosis. Android only; every other platform yields an empty
// stream. Never throws. Native side: GnssQualityPlugin.kt.
// See DECISIONS.md D68.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Channel name. Must match GnssQualityPlugin.CHANNEL exactly.
const String gnssQualityChannel = 'pontual/gnss_quality';

/// One GNSS quality sample. Signal quality only, no position.
class GnssQuality {
  /// Creates a sample.
  const GnssQuality({
    required this.satsUsed,
    required this.satsView,
    required this.meanSnrDb,
  });

  /// Satellites used in the current fix.
  final int satsUsed;

  /// Satellites in view.
  final int satsView;

  /// Mean carrier-to-noise density over used satellites, dB-Hz.
  final double meanSnrDb;

  /// Parses a native event map, or null when malformed. Never throws.
  static GnssQuality? fromMap(Object? event) {
    if (event is! Map) {
      return null;
    }
    final Object? used = event['satsUsed'];
    final Object? view = event['satsView'];
    final Object? snr = event['meanSnrDb'];
    if (used is! int || view is! int || snr is! num) {
      return null;
    }
    if (used < 0 || view < 0 || used > view) {
      return null;
    }
    return GnssQuality(
      satsUsed: used,
      satsView: view,
      meanSnrDb: snr.toDouble(),
    );
  }
}

/// Injectable native reader so tests never touch a platform channel
/// (an unmocked channel never resolves under testWidgets and would
/// hang the test).
typedef GnssQualityReader = Stream<GnssQuality> Function();

/// Watches GNSS quality on Android, empty everywhere else. Creating the
/// stream never throws; channel errors end the stream. Nothing is
/// sampled until the caller listens, so the native callback only runs
/// while a trip holds a subscription.
Stream<GnssQuality> watchGnssQuality({GnssQualityReader? reader}) {
  if (reader != null) {
    return reader();
  }
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const Stream.empty();
  }
  try {
    // Plain unit tests have no binding; behave like a non-Android
    // platform instead of throwing when the channel is touched (D71).
    ServicesBinding.instance;
  } catch (_) {
    return const Stream.empty();
  }
  return const EventChannel(gnssQualityChannel)
      .receiveBroadcastStream()
      .map(GnssQuality.fromMap)
      .where((GnssQuality? q) => q != null)
      .cast<GnssQuality>();
}

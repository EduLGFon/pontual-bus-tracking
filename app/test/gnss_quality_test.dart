// D68 tests: GNSS quality model parsing and the watch seam. The real
// native side only exists on Android hardware; here the injected reader
// stands in so no platform channel is ever touched.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/platform/android/gnss_quality.dart';

void main() {
  test('channel name matches the native plugin', () {
    // Contract with GnssQualityPlugin.CHANNEL; both change together.
    expect(gnssQualityChannel, 'pontual/gnss_quality');
  });

  test('fromMap parses a valid sample', () {
    final GnssQuality? q = GnssQuality.fromMap(<String, Object>{
      'satsUsed': 7,
      'satsView': 12,
      'meanSnrDb': 32.5,
    });
    expect(q, isNotNull);
    expect(q!.satsUsed, 7);
    expect(q.satsView, 12);
    expect(q.meanSnrDb, closeTo(32.5, 1e-9));
  });

  test('fromMap accepts integer SNR as double', () {
    final GnssQuality? q = GnssQuality.fromMap(<String, Object>{
      'satsUsed': 0,
      'satsView': 3,
      'meanSnrDb': 0,
    });
    expect(q, isNotNull);
    expect(q!.satsUsed, 0);
    expect(q.meanSnrDb, 0);
  });

  test('fromMap rejects malformed events', () {
    expect(GnssQuality.fromMap(null), isNull);
    expect(GnssQuality.fromMap('nope'), isNull);
    expect(GnssQuality.fromMap(<String, Object>{}), isNull);
    expect(
      GnssQuality.fromMap(<String, Object>{
        'satsUsed': '7',
        'satsView': 12,
        'meanSnrDb': 30,
      }),
      isNull,
    );
    expect(
      GnssQuality.fromMap(<String, Object>{
        'satsUsed': -1,
        'satsView': 12,
        'meanSnrDb': 30,
      }),
      isNull,
    );
    // More used than in view is impossible: a corrupt or spoofed event.
    expect(
      GnssQuality.fromMap(<String, Object>{
        'satsUsed': 9,
        'satsView': 4,
        'meanSnrDb': 30,
      }),
      isNull,
    );
  });

  test('watch yields the injected reader stream', () async {
    // ignore: close_sinks - single-subscription test stream.
    final StreamController<GnssQuality> fake = StreamController<GnssQuality>();
    final Stream<GnssQuality> stream = watchGnssQuality(
      reader: () => fake.stream,
    );
    final Future<GnssQuality> next = stream.first;
    fake.add(const GnssQuality(satsUsed: 5, satsView: 9, meanSnrDb: 28));
    final GnssQuality q = await next.timeout(const Duration(seconds: 5));
    expect(q.satsUsed, 5);
    await fake.close();
  });

  test('watch creates a stream without touching the channel', () {
    // Creation is lazy and sync: no native call, no throw, even
    // off-device. Nothing is sampled until someone listens.
    expect(watchGnssQuality(), isA<Stream<GnssQuality>>());
  });
}

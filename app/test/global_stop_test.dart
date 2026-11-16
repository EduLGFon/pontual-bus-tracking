// Tolerant parsing tests for the global stop and stop arrivals models.
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/domain/learning/global_stop.dart';

void main() {
  test('global stop parses contract keys and unknown keys', () {
    final GlobalStop stop = GlobalStop.fromJson(<String, dynamic>{
      'id': 'stop-1',
      'lat': -18.72,
      'lng': -39.85,
      'r': 25,
      'n': 12,
      'name': 'Centro',
      'future': <String, dynamic>{'ignored': true},
      'lines': <dynamic>[
        <String, dynamic>{'l': 66, 'd': 0, 's': 'member-1'},
        <String, dynamic>{'l': 'bad', 'd': null},
        'not-a-map',
      ],
    });
    expect(stop.id, 'stop-1');
    expect(stop.lat, -18.72);
    expect(stop.lng, -39.85);
    expect(stop.radiusM, 25);
    expect(stop.passes, 12);
    expect(stop.name, 'Centro');
    expect(stop.lines.length, 2);
    expect(stop.lines.first.lineId, 66);
    expect(stop.lines.first.direction, 0);
    expect(stop.lines.first.stopId, 'member-1');
    expect(stop.lines.last.lineId, 0);
    expect(stop.lines.last.stopId, '');
  });

  test('global stop tolerates missing optional fields', () {
    final GlobalStop stop = GlobalStop.fromJson(<String, dynamic>{
      'id': 'stop-2',
      'lat': -18.7,
      'lng': -39.8,
    });
    expect(stop.radiusM, 30);
    expect(stop.passes, 0);
    expect(stop.name, isNull);
    expect(stop.lines, isEmpty);
  });

  test('stop line ref parses aliases and garbage defensively', () {
    final StopLineRef ref = StopLineRef.fromJson(<String, dynamic>{
      'line': 7,
      'direction': 1,
      'stop': 'member-7',
    });
    expect(ref.lineId, 7);
    expect(ref.direction, 1);
    expect(ref.stopId, 'member-7');

    final StopLineRef empty = StopLineRef.fromJson(<String, dynamic>{});
    expect(empty.lineId, 0);
    expect(empty.direction, 0);
    expect(empty.stopId, '');
  });

  test('validity rejects empty ids and points outside the service area', () {
    expect(const GlobalStop(id: '', lat: -18.72, lng: -39.85).isValid, isFalse);
    expect(const GlobalStop(id: 's', lat: 0, lng: 0).isValid, isFalse);
    expect(const GlobalStop(id: 's', lat: -18.72, lng: -39.85).isValid, isTrue);
  });

  test('stop arrivals parse items and tolerate unknown or missing keys', () {
    final StopArrivals arrivals = StopArrivals.fromJson(<String, dynamic>{
      'id': 'stop-1',
      'now': 1730000000,
      'extra': true,
      'items': <dynamic>[
        <String, dynamic>{
          'line': 66,
          'code': '66-centro-ifes-ufes',
          'vehicle': 12,
          'eta_s': 240,
          'conf': 'high',
          'n': 38,
          'm': 'learned',
          'future': 'ignored',
        },
        <String, dynamic>{'line': 67},
        'not-a-map',
      ],
    });
    expect(arrivals.stopId, 'stop-1');
    expect(arrivals.nowS, 1730000000);
    expect(arrivals.items.length, 2);
    expect(arrivals.items.first.lineId, 66);
    expect(arrivals.items.first.code, '66-centro-ifes-ufes');
    expect(arrivals.items.first.vehicleId, 12);
    expect(arrivals.items.first.etaS, 240);
    expect(arrivals.items.first.confidence, 'high');
    expect(arrivals.items.first.sampleCount, 38);
    expect(arrivals.items.first.method, 'learned');
    expect(arrivals.items.last.vehicleId, 0);
    expect(arrivals.items.last.etaS, 0);
    expect(arrivals.items.last.method, '');
  });

  test('stop arrivals tolerate a missing items list', () {
    final StopArrivals arrivals = StopArrivals.fromJson(<String, dynamic>{
      'stopId': 'stop-3',
    });
    expect(arrivals.stopId, 'stop-3');
    expect(arrivals.nowS, 0);
    expect(arrivals.items, isEmpty);
  });
}

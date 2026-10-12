// Offline map configuration: theme-to-style selection, PMTiles URL
// resolution and the no-third-party-host invariant. Style JSON validity
// is checked from the real asset files so schema drift fails fast.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/features/map/offline_map.dart';
import 'package:pontual/features/map/tile_source.dart';

Map<String, dynamic> _loadStyle(String path) {
  final String text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

void main() {
  test('theme selects the matching style asset', () {
    expect(
      mapStyleAssetFor(Brightness.light),
      'assets/map/protomaps-light.json',
    );
    expect(mapStyleAssetFor(Brightness.dark), 'assets/map/protomaps-dark.json');
  });

  test('pmtiles URL resolution covers file and static host', () {
    expect(
      resolvePmtilesUrl('file:///data/sao_mateus.pmtiles'),
      'file:///data/sao_mateus.pmtiles',
    );
    expect(
      resolvePmtilesUrl('https://static.example'),
      'https://static.example/maps/sao_mateus.pmtiles',
    );
  });

  test('style substitution fills the tiles URL and keeps unknown docs', () {
    expect(
      substitutePmtilesUrl('pmtiles://{PMTILES_URL}', 'file:///a.pmtiles'),
      'pmtiles://file:///a.pmtiles',
    );
    expect(substitutePmtilesUrl('{"a":1}', 'file:///a.pmtiles'), '{"a":1}');
  });

  for (final String path in <String>[
    'assets/map/protomaps-light.json',
    'assets/map/protomaps-dark.json',
  ]) {
    test('$path is a valid self-contained style', () {
      final Map<String, dynamic> style = _loadStyle(path);
      expect(style['version'], 8);
      expect(style['glyphs'], isNot(contains('http')));
      expect(styleHasNoThirdPartyHosts(style), isTrue);
      final Map<String, dynamic> sources =
          style['sources'] as Map<String, dynamic>;
      expect(sources, contains('protomaps'));
      final List<dynamic> layers = style['layers'] as List<dynamic>;
      expect(layers.length, greaterThan(10));
      final Set<String> ids = <String>{
        for (final dynamic l in layers)
          (l as Map<String, dynamic>)['id'] as String,
      };
      for (final String required in <String>[
        'background',
        'water',
        'roads-major',
        'roads-labels',
        'bus-stops',
        'places-locality',
      ]) {
        expect(ids, contains(required), reason: path);
      }
    });
  }

  test('dark style has no glaring white areas', () {
    final String text = File('assets/map/protomaps-dark.json')
        .readAsStringSync()
        .toLowerCase();
    expect(text, isNot(contains('#ffffff')));
    expect(text, isNot(contains('#fff')));
  });

  test('tile source uses the app identifier and capped cache', () {
    expect(tileUserAgent, 'com.spotnik.pontual');
    expect(tileCacheMaxBytes, 50 * 1000 * 1000);
    final TileLayer layer = osmTileLayer(
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      caching: const DisabledMapCachingProvider(),
    );
    expect(layer.urlTemplate, contains('tile.openstreetmap.org'));
    expect(layer.minZoom, mapMinZoom);
    expect(layer.maxZoom, mapMaxZoom);
  });

  test('failed tiles are evicted when pruned, never kept as errors', () {
    final TileLayer layer = osmTileLayer(
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      caching: const DisabledMapCachingProvider(),
    );
    expect(layer.evictErrorTileStrategy, EvictErrorTileStrategy.dispose);
  });

  test('error callback and reset stream are wired only when provided', () {
    final TileLayer plain = osmTileLayer(
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      caching: const DisabledMapCachingProvider(),
    );
    expect(plain.errorTileCallback, isNull);
    expect(plain.reset, isNull);

    final StreamController<void> reset = StreamController<void>();
    addTearDown(() {
      unawaited(reset.close());
    });
    bool errors = false;
    final TileLayer live = osmTileLayer(
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      caching: const DisabledMapCachingProvider(),
      reset: reset.stream,
      onTileError: () => errors = true,
    );
    expect(live.errorTileCallback, isNotNull);
    expect(live.reset, isNotNull);
    expect(errors, isFalse);
  });

  test('tile reload backoff doubles per attempt within the cap', () {
    expect(tileReloadDelay(0), const Duration(seconds: 2));
    expect(tileReloadDelay(1), const Duration(seconds: 4));
    expect(tileReloadDelay(2), const Duration(seconds: 8));
    expect(tileReloadDelay(3), const Duration(seconds: 16));
    expect(tileReloadDelay(99), const Duration(seconds: 32));
    expect(maxTileReloadAttempts, 3);
  });
}

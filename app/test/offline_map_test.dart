// Offline map configuration: theme-to-style selection, PMTiles URL
// resolution and the no-third-party-host invariant. Style JSON validity
// is checked from the real asset files so schema drift fails fast.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/features/map/offline_map.dart';

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
}

// Tile source compliance: the OSM identifier and the capped cache live
// behind this seam so the map can be replaced without touching widgets.
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pontual/features/map/tile_source.dart';

void main() {
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
}

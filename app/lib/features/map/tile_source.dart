// Tile source abstraction. OSM raster tiles with the built-in cache
// capped at 50 MB live behind this seam so a self-hosted backend can
// replace the URL without touching widgets. See PLAN.md D12 and S3.
// Poor connections are served by the organic cache (tiles persist once
// viewed); programmatic prefetch or bundling of OSM tiles stays
// forbidden by the OSM tile policy and AGENTS.md 15. See DECISIONS.md D-U26.
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Real application identifier sent as the tile User-Agent.
/// Generic defaults get blocked by OSM without notice.
const String tileUserAgent = 'com.spotnik.pontual';

/// Tile cache cap in bytes. The library default of 1 GB is far too large.
const int tileCacheMaxBytes = 50 * 1000 * 1000;

/// São Mateus area bounds constraining pan and zoom.
final LatLngBounds mapBounds = LatLngBounds(
  const LatLng(-19.05, -40.25),
  const LatLng(-18.40, -39.55),
);

/// Minimum zoom. No bulk-friendly deep zooms.
const double mapMinZoom = 12;

/// Maximum zoom.
const double mapMaxZoom = 17;

/// Builds the OSM tile layer for [tileUrlTemplate]. Pass [httpClient] in
/// tests to avoid real network traffic.
TileLayer osmTileLayer(
  String tileUrlTemplate, {
  MapCachingProvider? caching,
  http.Client? httpClient,
}) {
  return TileLayer(
    urlTemplate: tileUrlTemplate,
    userAgentPackageName: tileUserAgent,
    tileProvider: NetworkTileProvider(
      httpClient: httpClient,
      cachingProvider:
          caching ??
          BuiltInMapCachingProvider.getOrCreateInstance(
            maxCacheSize: tileCacheMaxBytes,
          ),
    ),
    minZoom: mapMinZoom,
    maxZoom: mapMaxZoom,
  );
}

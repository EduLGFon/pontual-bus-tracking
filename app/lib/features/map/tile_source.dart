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
/// Note: the built-in provider is disabled on web, so the PWA refetches
/// every tile over the network. Only Android gets this file cache.
const int tileCacheMaxBytes = 50 * 1000 * 1000;

/// Maximum automatic tile reload attempts per error burst. Throttled
/// bursts from the public raster host fail together; a small bounded
/// retry recovers the visible map without a user gesture.
const int maxTileReloadAttempts = 3;

/// Base delay before the first automatic tile reload.
const Duration tileReloadBaseDelay = Duration(seconds: 2);

/// Quiet period after which a tile error starts a new retry burst,
/// resetting the attempt budget.
const Duration tileErrorBurstWindow = Duration(seconds: 30);

/// Backoff delay before reload attempt [attempt] (zero-based): 2 s, 4 s,
/// 8 s, capped to keep recovery prompt on slow links.
Duration tileReloadDelay(int attempt) {
  final int shift = attempt < 0 ? 0 : attempt;
  final int factor = 1 << (shift > 4 ? 4 : shift);
  return tileReloadBaseDelay * factor;
}

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
///
/// [reset] forces the layer to reload the visible tiles when the stream
/// emits, used for the bounded automatic retry after throttled bursts.
/// [onTileError] fires once per failed tile, without any tile coordinates,
/// so the caller can count failures and schedule that retry. Failed tiles
/// are evicted when pruned, so coming back to an area refetches it instead
/// of showing a stale error.
TileLayer osmTileLayer(
  String tileUrlTemplate, {
  MapCachingProvider? caching,
  http.Client? httpClient,
  Stream<void>? reset,
  void Function()? onTileError,
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
    reset: reset,
    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
    errorTileCallback: onTileError == null
        ? null
        : (TileImage tile, Object error, StackTrace? stackTrace) =>
              onTileError(),
  );
}

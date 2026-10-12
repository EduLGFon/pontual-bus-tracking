// Offline map configuration. Selects the bundled MapLibre style matching
// the app theme and resolves the city PMTiles location per platform.
// The styles use only the Protomaps basemap schema (v4) and bundled
// glyphs: no runtime request to any third-party tile, font or sprite
// host. The renderer integration lands behind this seam; until then the
// app keeps the OSM raster fallback. See docs/maps.md and DECISIONS.md D29.
import 'package:flutter/material.dart';

/// Bundled city tiles, copied to app storage on first run on Android
/// (native renderers read file paths, never flutter assets) and served
/// with HTTP range requests on web. Not bundled in the APK: at 44 MB the
/// file would break the RNF14 size budget, so it is fetched once from
/// our own static host. See docs/maps.md.
const String offlinePmtilesFileName = 'sao_mateus.pmtiles';

/// Path of the tiles on our static host (GitHub Pages), next to the
/// style glyphs. Same origin as the app data, no third party involved.
const String offlinePmtilesStaticPath = 'maps/sao_mateus.pmtiles';

/// Bundled light style for the Protomaps schema.
const String offlineLightStyleAsset = 'assets/map/protomaps-light.json';

/// Bundled dark style for the Protomaps schema.
const String offlineDarkStyleAsset = 'assets/map/protomaps-dark.json';

/// Glyph stack used by both styles. Generated once from Noto Sans
/// (SIL OFL 1.1) and served from our own host; see docs/maps.md.
const String offlineFontStack = 'Noto Sans Regular';

/// Placeholder in the style JSON replaced with the real tiles URL.
const String pmtilesUrlToken = '{PMTILES_URL}';

/// Maximum tile zoom stored in the file. The map overzooms vector data
/// beyond this: geometry stays sharp, only detail stops increasing.
const int offlineTilesMaxZoom = 15;

/// Picks the style asset matching the app theme.
String mapStyleAssetFor(Brightness brightness) {
  return brightness == Brightness.dark
      ? offlineDarkStyleAsset
      : offlineLightStyleAsset;
}

/// Resolves the tiles URL for the style source: a local file URL after
/// the first-run copy on Android, or the static-host URL (range reads)
/// on web. [base] is the file URL or the static origin.
String resolvePmtilesUrl(String base) {
  return base.endsWith(offlinePmtilesFileName)
      ? base
      : '$base/$offlinePmtilesStaticPath';
}

/// Substitutes the tiles URL into a loaded style document. Returns the
/// document unchanged when the token is absent (forward compatible).
String substitutePmtilesUrl(String styleJson, String pmtilesUrl) {
  return styleJson.replaceAll(pmtilesUrlToken, pmtilesUrl);
}

/// True when every layer of a parsed style document references only the
/// bundled source and relative glyphs: no third-party host may appear.
/// Used by tests and the pre-release privacy check.
bool styleHasNoThirdPartyHosts(Map<String, dynamic> style) {
  final Object? glyphs = style['glyphs'];
  if (glyphs is String && _isAbsoluteHttp(glyphs)) {
    return false;
  }
  final Object? sources = style['sources'];
  if (sources is Map) {
    for (final Object? source in sources.values) {
      if (source is Map) {
        final Object? url = source['url'];
        if (url is String &&
            _isAbsoluteHttp(url) &&
            !url.contains(pmtilesUrlToken)) {
          return false;
        }
      }
    }
  }
  return true;
}

bool _isAbsoluteHttp(String url) {
  return url.startsWith('http://') || url.startsWith('https://');
}

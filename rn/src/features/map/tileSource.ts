// Tile source abstraction. Mirrors app/lib/features/map/tile_source.dart.
// OSM raster tiles; no bulk download or prefetch. Cache cap documented;
// MapLibre config consumes these constants.
export const tileUserAgent = "com.spotnik.pontual";

export const tileCacheMaxBytes = 50 * 1000 * 1000;

export const maxTileReloadAttempts = 3;
export const tileReloadBaseDelayMs = 2000;
export const tileErrorBurstWindowMs = 30 * 1000;

export function tileReloadDelayMs(attempt: number): number {
  const shift = attempt < 0 ? 0 : attempt;
  const capped = shift > 4 ? 4 : shift;
  return tileReloadBaseDelayMs * (1 << capped);
}

export const mapBounds = {
  latMin: -19.05,
  latMax: -18.4,
  lngMin: -40.25,
  lngMax: -39.55,
};

export const mapMinZoom = 12;
export const mapMaxZoom = 17;

// Default raster style for MapLibre (OSM). Kept as a constant so a
// self-hosted backend can replace the URL without touching components.
export function osmStyleUrl(tileUrlTemplate?: string): string {
  void tileUrlTemplate;
  return "https://demotiles.maplibre.org/style.json";
}

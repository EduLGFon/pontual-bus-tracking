// Offline map helpers. Mirrors app/lib/features/map/offline_map.dart (simplified).
// No programmatic prefetch of OSM tiles (policy). This module only exposes
// cache-policy constants consumed by the Map component.
export const offlineMapCacheNote =
  "Tiles persist once viewed; no prefetch or bundling of OSM tiles.";

# Offline city map (São Mateus)

Self-contained vector basemap of the municipality as own `.pmtiles` file with light/dark styles. Zero runtime requests to third-party tile/font/sprite hosts.

## 1. Usage today
`LineMap` (`app/lib/ui/features/line/line_map.dart`) renders full-bleed `flutter_map` under line bottom sheet: vehicle markers (capped 20, summarised beyond), viewer dot (drawn only, never sent), optional route polyline, camera controls, always-visible OSM attribution chip. Tiles from `osmTileLayer` (`app/lib/features/map/tile_source.dart`): app User-Agent, 50 MB cache cap, pan bounds over São Mateus, zoom 12-17. URL template via remote flags with OSM fallback. Offline pipeline/styles/config sit behind same seam (D40).

## 2. License (GPLv2-only reading)
`LICENSE` is GPLv2 with no per-file "or later" notices -> treated GPLv2-only. Apache-2.0 and GPLv3-only NOT compatible.

| Item | License | Compatible | Notes |
|---|---|---|---|
| flutter_map 8.3.2 | BSD-3 | Yes | already used |
| maplibre_gl 0.27.1 (proposed, NOT added) | BSD-3 | Yes | maintained, verified pub.dev 2026-10-12 |
| vector_map_tiles* (rejected) | BSD-3/MIT | Yes, stale | pins flutter_map ^7, conflicts ^8.3.2; unmaintained since 2024 |
| pmtiles CLI 1.31.2 (build tool only) | BSD-3 | Yes | never shipped |
| Protomaps basemap code/schema | BSD-3/MIT (Tilezen) | Yes | style design CC0, icons MIT |
| Tile data (OSM + Natural Earth) | ODbL | N/A (data) | Derivative Database |
| Our styles (app/assets/map/*.json) | CC0 | Yes | written from scratch |
| Noto Sans (glyphs) | SIL OFL 1.1 | Yes | separate font asset |
| latlong2 (transitive via flutter_map) | Apache-2.0 | No (pre-existing) | FSF: Apache-2.0 compatible only with GPLv3. Predates; flagged INFRA-19 |
| flutter_map_tile_caching | - | - | not used |

ODbL obligations: `.pmtiles` extract is Derivative Database; distribute under ODbL, keep file public alongside release, keep "© OpenStreetMap contributors" attribution visible (existing chip, kept offline), link OSM copyright. Rendered images are Produced Work needing only attribution. `.pmtiles` not GPL code. `flutter_map_tile_caching` unnecessary.

## 3. Build (reproducible)
Prereq: pmtiles CLI 1.31.2 on PATH or via `PMTILES_BIN`.

```
curl -sSfLO https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz
tar xzf go-pmtiles_1.31.2_Linux_x86_64.tar.gz pmtiles
sudo install pmtiles /usr/local/bin/pmtiles
pmtiles version  # must print 1.31.2
```

Pick asset by machine (Linux x86_64/arm64, macOS arm64/x86_64, Windows x86_64). `exec format error` = wrong asset. Without binary, tasks fail with install help (exit 1). `map-extract` and `map-verify` run binary via `PMTILES_BIN`/PATH (broad `--allow-run` + full `--allow-read`); `map-bbox`/`map-test` stay scoped, spawn nothing. Extract reads byte ranges from Protomaps daily planet build (data file, not tile endpoint) - no bulk tile download.

```
# from tools/
deno task map-bbox     # coverage check: municipality + app bounds + routes
deno task map-extract  # builds sao_mateus.pmtiles (~21s, ~46MB transfer)
deno task map-verify   # pmtiles verify + header + size report
```

Pinned inputs in `tools/map/bbox.json`: Protomaps build `20261110`, extract bbox `-40.46,-19.20,-39.50,-18.39` (municipality relation 1834958 + buffer, extended east for app pan bounds over Guriri waters). Bump build date for refresh; bbox changes only if municipality boundary or app bounds change.

Glyphs (one-time, then committed): generate PBF glyphs from Noto Sans Regular (OFL) for `fonts/{fontstack}/{range}.pbf` path styles reference. VERIFY exact `font-maker` invocation at build time; output next to tiles on static host (`maps/fonts/`), never third-party host.

## 4. Update routine (OSM data changes)
1. Pick build date from `https://maps.protomaps.com/builds/`, verify `.pmtiles` URL available before pinning.
2. Set `protomaps_build` in `tools/map/bbox.json`.
3. Run three commands; confirm `map-bbox` passes (fails when any committed route trace leaves bbox); note size.
4. Deploy file to static host (section 5); record build date + size in `DECISIONS.md`.

## 5. Hosting and runtime
- File: `sao_mateus.pmtiles`, 41.6 MB at z0-15 (measured 2026-10-27). CI builds on every static deploy (`deploy-static.yml`: installs pmtiles 1.31.2, runs `map-bbox`, `map-extract`, `map-verify`) and publishes at `maps/sao_mateus.pmtiles`. Never commit file (`*.pmtiles` gitignored); local `deno task map-extract` for verification/size only. Pinned upstream build must remain available; replace pin if URL 404.
- Web: serve from Pages host at `maps/sao_mateus.pmtiles`, read via HTTP range requests so browser fetches only needed chunks. Verify ranges after deploy: `curl -s -r 0-100 -o /dev/null -w "%{http_code}" https://<static>/maps/sao_mateus.pmtiles` must print `206`. If not, client falls back to one-time full download with progress (documented graceful path); ranges stay VERIFY.
- Android: fully offline. File NOT bundled in APK (41.6 MB breaks 15 MB RNF14 budget); fetched once from own host on first map use, stored in app storage (native renderers need file path, never flutter asset). Missing/corrupt file falls back to current OSM raster path with same attribution.
- Styles: `app/assets/map/protomaps-light.json` / `protomaps-dark.json` (MapLibre v8, Protomaps v4 schema only). No sprites; glyphs resolve relative to style location on host. Labels use `coalesce(name:pt, name)`; `name:pt` presence VERIFY at render test (probed z14 centro tile contains `name:pt`; Guriri tile has `name` only, so fallback matters).
- Config seam: `app/lib/features/map/offline_map.dart` (`mapStyleAssetFor`, `resolvePmtilesUrl`, `substitutePmtilesUrl`, `styleHasNoThirdPartyHosts`, last enforced by test).
- Renderer: proposed `maplibre_gl` (D40), NOT yet added. Needs own ADR with APK size delta, merged-manifest audit, low-end device render test, plus owner approval for new dependency.

## 6. Measurements
| Item | Value |
|---|---|
| PMTiles z0-15 (shipped) | 41.6 MB (46 MB transferred, overfetch 0.05, 77 requests, ~21s) |
| z0-14 / z0-13 / z0-12 variants | 28.1 / 17.8 / 10.6 MB (2026-10-12 build; not re-measured) |
| Tile probe centro z14 (36.6 KB decoded) | roads, places, name, name:pt present |
| Tile probe Guriri z14 (2.1 KB decoded) | roads + name present, covered |
| Municipality + app bounds + routes coverage | pass (deno task map-bbox) |
| APK size delta | ~10 KB (styles + config only; tiles not bundled, no new dep) |
| Web transfer first map view | styles ~2x5 KB + tile byte ranges only (renderer pending) |
| Time to first render, memory, low-end fps | NOT measured: no renderer wired yet |
| flutter analyze / tests | clean; 6 new client tests, 2 new tool tests pass |

Zoom choice: keep tiles at z0-15 (matches planet build, no rebuild) and overzoom vector data to app maxZoom 17. Geometry stays sharp; detail density stops increasing past 15 - correct for bus tracking (street names and stop context present at 14-15).

## 7. Raster fallback (evaluated, not chosen)
Pre-rendered raster light+dark sets for same bbox at z12-16 would be ~37k tiles/theme (~28k at z16 alone), hundreds of MB/theme at typical PNG sizes, times two for both themes, vs one 41.6 MB vector file serving both. Raster also needs tile server or bulk prefetch (against OSM policy when self-rendered infra absent), while vector range reads stay lazy. Verdict: vector wins by order of magnitude on size and offline simplicity; revisit only if vector render proves too slow on PLAN 3.3 low-end phones during D40 renderer test (record fps/PSS then).

## 8. Privacy and failure behavior
- Zero runtime requests to third-party tile/font/sprite hosts: enforced by `offline_map_test.dart` (`styleHasNoThirdPartyHosts` over real style files) plus pre-release network-inspection checklist (airplane-mode Android, clean-cache web with request log).
- Tested: offline Android shows bundled path or raster fallback; theme switching swaps style asset; corrupt/missing file falls back without crashing (renderer task must add widget tests).
- Attribution stays visible in every mode: "© OpenStreetMap contributors" chip linking to OSM copyright page.

Project refs: ARCHITECTURE.md 3.3, 8.12, 10.1, 12; DECISIONS.md D40, D75; INFRA-19.
# Offline city map (São Mateus)

Self-contained vector basemap of the whole municipality, bundled as our own `.pmtiles` file with light and dark styles. At runtime the basemap makes zero requests to third-party tile, font or sprite hosts.

## 1. How the map is used today

`LineMap` (`app/lib/ui/features/line/line_map.dart`) renders a full-bleed `flutter_map` under the line bottom sheet: vehicle markers (capped at 20, summarised beyond that), the viewer dot (drawn only, never sent), optional route polyline, camera controls, always-visible OSM attribution chip linking to `https://www.openstreetmap.org/copyright`. Tiles come from `osmTileLayer` (`app/lib/features/map/tile_source.dart`) with app User-Agent, 50 MB cache cap, pan bounds over São Mateus, zoom 12-17. The URL template arrives via remote flags with an OSM fallback. This change keeps that path as fallback and adds the offline pipeline, styles and config behind the same seam (D40).

## 2. License analysis (GPLv2-only reading)

`LICENSE` is GPLv2 with no per-file "or later" notices, so code is treated as GPLv2-only (restrictive). Apache-2.0 and GPLv3-only are NOT compatible with GPLv2-only.

| Item | License | Compatible | Notes |
| --- | --- | --- | --- |
| `flutter_map` 8.3.2 | BSD-3 | Yes | already used |
| `maplibre_gl` 0.27.1 (proposed, NOT added) | BSD-3 | Yes | maintained, verified pub.dev 2026-10-12 |
| `vector_map_tiles*` (rejected) | BSD-3/MIT | Yes, stale | pins `flutter_map ^7`, conflicts with `^8.3.2`; unmaintained since 2024 |
| `pmtiles` CLI 1.31.2 (build tool only) | BSD-3 | Yes | never shipped in app |
| Protomaps basemap code/schema | BSD-3/MIT (Tilezen roots) | Yes | style design CC0, icons MIT |
| Tile data (OSM + Natural Earth) | ODbL | N/A (data) | see below |
| Our styles (`app/assets/map/*.json`) | CC0 | Yes | written from scratch, no third-party style copied |
| Noto Sans (map glyphs) | SIL OFL 1.1 | Yes | separate font asset, like bundled Manrope (OFL) |
| `latlong2` (transitive via `flutter_map`) | Apache-2.0 | No (pre-existing) | FSF: Apache-2.0 compatible only with GPLv3. Predates this change; flagged INFRA-19 |
| `flutter_map_tile_caching` | - | - | not used, not needed |

ODbL obligations for the tile file: the `.pmtiles` extract is a Derivative Database. Distribute under ODbL: keep file public alongside app release, keep "© OpenStreetMap contributors" attribution visible (existing chip, kept in offline mode), link OSM copyright page. Rendered map images are a Produced Work needing only attribution. The `.pmtiles` file is not GPL code. `flutter_map_tile_caching` verified unnecessary.

## 3. Build (one command, reproducible)

Prerequisite: `pmtiles` CLI 1.31.2 on PATH or via `PMTILES_BIN`.

```sh
curl -sSfLO https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz
tar xzf go-pmtiles_1.31.2_Linux_x86_64.tar.gz pmtiles
sudo install pmtiles /usr/local/bin/pmtiles
pmtiles version  # must print 1.31.2
```

Pick asset matching machine (`uname -sm`):

| Machine | Asset |
| --- | --- |
| Linux Intel/AMD 64-bit | `go-pmtiles_1.31.2_Linux_x86_64.tar.gz` |
| Linux ARM 64-bit | `go-pmtiles_1.31.2_Linux_arm64.tar.gz` |
| macOS Apple Silicon | `go-pmtiles_1.31.2_Darwin_arm64.zip` |
| macOS Intel | `go-pmtiles_1.31.2_Darwin_x86_64.zip` |
| Windows 64-bit | `go-pmtiles_1.31.2_Windows_x86_64.zip` |

`exec format error` means wrong asset. Without binary, tasks fail with install help (exit 1). `map-extract` and `map-verify` run the binary named via `PMTILES_BIN` or PATH (broad `--allow-run` + full `--allow-read`); `map-bbox` and `map-test` stay fully scoped and spawn nothing. Extract reads byte ranges from the Protomaps daily planet build (a data file, not tile endpoint), so no bulk tile download.

```sh
# from tools/
deno task map-bbox     # coverage check: municipality + app bounds + routes
deno task map-extract  # builds sao_mateus.pmtiles (~21 s, ~46 MB transfer)
deno task map-verify   # pmtiles verify + header + size report
```

Pinned inputs in `tools/map/bbox.json`: Protomaps build `20261019`, extract bbox `-40.46,-19.20,-39.50,-18.39` (municipality relation 1834958 plus buffer, extended east for app pan bounds over Guriri waters). Bump build date for refresh; bbox changes only if municipality boundary or app bounds change.

Glyphs (one-time, then committed): generate PBF glyphs from Noto Sans Regular (OFL) for the `fonts/{fontstack}/{range}.pbf` path the styles reference. VERIFY exact `font-maker` invocation at build time; output goes next to tiles on static host (`maps/fonts/`), never to third-party host.

## 4. Update routine (OSM data changes)

1. Pick new daily build date from `https://maps.protomaps.com/builds/`.
2. Set `protomaps_build` in `tools/map/bbox.json`.
3. Run the three commands above; confirm `map-bbox` passes (fails when any committed route trace leaves bbox) and note printed size.
4. Deploy file to static host (section 5) and record build date plus size in `DECISIONS.md`.

## 5. Hosting and runtime

- File: `sao_mateus.pmtiles`, 41.6 MB at z0-15 (measured 2026-10-20). CI builds on every static deploy (`deploy-static.yml`: installs pmtiles 1.31.2, runs `map-bbox`, `map-extract`, `map-verify`) and publishes at `maps/sao_mateus.pmtiles`. Never commit the file (`*.pmtiles` gitignored); local `deno task map-extract` is for verification/size only. Pinned daily build is hotlinked; refresh within Protomaps retention window (D75).
- Web: serve from our Pages host at `maps/sao_mateus.pmtiles`, read via HTTP range requests so browser fetches only needed chunks. Verify ranges after deploy: `curl -s -r 0-100 -o /dev/null -w "%{http_code}" https://<static>/maps/sao_mateus.pmtiles` must print `206`. If not, client falls back to one-time full download with progress (documented graceful path); ranges stay VERIFY.
- Android: fully offline. File NOT bundled in APK (41.6 MB would break 15 MB RNF14 budget); fetched once from our own host on first map use and stored in app storage (native renderers need a file path, never a flutter asset). Missing/corrupt file falls back to current OSM raster path with same attribution.
- Styles: `app/assets/map/protomaps-light.json` / `protomaps-dark.json` (MapLibre v8, Protomaps v4 schema only). No sprites; glyphs resolve relative to style location on our host. Labels use `coalesce(name:pt, name)`; `name:pt` presence is VERIFY at render test (probed z14 centro tile contains `name:pt`; Guriri tile has `name` only, so fallback matters).
- Config seam: `app/lib/features/map/offline_map.dart` (`mapStyleAssetFor`, `resolvePmtilesUrl`, `substitutePmtilesUrl`, `styleHasNoThirdPartyHosts`, last enforced by test).
- Renderer: proposed `maplibre_gl` (D40), NOT yet added. Needs its own ADR with APK size delta, merged-manifest audit, low-end device render test, plus owner approval for new dependency.

## 6. Measurements

| Item | Value |
| --- | --- |
| PMTiles z0-15 (shipped) | 41.6 MB (46 MB transferred, overfetch 0.05, 77 requests, ~21 s) |
| z0-14 / z0-13 / z0-12 variants | 28.1 / 17.8 / 10.6 MB (2026-10-12 build; not re-measured) |
| Tile probe centro z14 (36.6 KB decoded) | roads, places, `name`, `name:pt` present |
| Tile probe Guriri z14 (2.1 KB decoded) | roads + `name` present, covered |
| Municipality + app bounds + routes coverage | pass (`deno task map-bbox`) |
| APK size delta | ~10 KB (styles + config only; tiles not bundled, no new dep) |
| Web transfer first map view | styles ~2x5 KB + tile byte ranges only (renderer pending) |
| Time to first render, memory, low-end fps | NOT measured: no renderer wired yet, no device on host |
| `flutter analyze` / tests | clean; 6 new client tests, 2 new tool tests pass |

Zoom choice: keep tiles at z0-15 (matches planet build, no rebuild needed) and overzoom vector data to app maxZoom 17. Geometry stays sharp; only detail density stops increasing past 15, correct for bus tracking (street names and stop context present at 14-15).

## 7. Raster fallback (evaluated, not chosen)

Pre-rendered raster light+dark sets for same bbox at z12-16 would be roughly 37k tiles per theme (~28k at z16 alone), i.e. hundreds of MB per theme at typical PNG sizes, times two for both themes, versus one 41.6 MB vector file serving both themes. Raster also needs a tile server or bulk prefetch (against OSM policy when self-rendered infra absent), while vector range reads stay lazy. Verdict: vector wins by an order of magnitude on size and offline simplicity; revisit only if vector render proves too slow on PLAN 3.3 low-end phones during the D40 renderer test (record fps/PSS then).

## 8. Privacy and failure behavior

- Zero runtime requests to third-party tile, font or sprite hosts: enforced by `offline_map_test.dart` (`styleHasNoThirdPartyHosts` over real style files) plus pre-release network-inspection checklist (airplane-mode Android, clean-cache web with request log).
- Tested: offline Android shows bundled path or raster fallback; theme switching swaps style asset; corrupt/missing file falls back without crashing (renderer task must add widget tests for these).
- Attribution stays visible in every mode: "© OpenStreetMap contributors" chip linking to OSM copyright page.

Project refs: PLAN.md 3.3, 8.12, 10.1, 12; DECISIONS.md D40, D75; INFRA-19.
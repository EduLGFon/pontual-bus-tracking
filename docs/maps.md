# Offline city map (São Mateus)

Self-contained vector basemap of the whole municipality, bundled as our own
`.pmtiles` file with a light and a dark style. At runtime the basemap makes
zero requests to third-party tile, font or sprite hosts.

## 1. How the map is used today

`LineMap` (`app/lib/ui/features/line/line_map.dart`) renders a full-bleed
`flutter_map` under the line bottom sheet: vehicle markers (capped at 20,
summarised beyond that), the viewer dot (drawn only, never sent anywhere),
the optional route polyline, camera controls and the always-visible OSM
attribution chip linking to `https://www.openstreetmap.org/copyright`.
Tiles come from `osmTileLayer` (`app/lib/features/map/tile_source.dart`)
with the app User-Agent, a 50 MB cache cap, pan bounds over São Mateus and
zoom 12 to 17. The URL template arrives via remote flags with an OSM
fallback. This change keeps that path as the fallback and adds the offline
pipeline, styles and config behind the same seam (D40).

## 2. License analysis (GPLv2 project)

`LICENSE` is the GPLv2 text with no per-file "or later" notices in the
tree, so this analysis treats the code as **GPLv2-only** (restrictive
reading). Key: Apache-2.0 and GPLv3-only are NOT compatible with
GPLv2-only.

| Item | License | Compatible with GPLv2-only | Notes |
| ---- | ------- | -------------------------- | ----- |
| `flutter_map` 8.3.2 | BSD-3-Clause | Yes | already used |
| `maplibre_gl` 0.27.1 (proposed renderer, NOT added) | BSD-3-Clause | Yes | maintained, verified on pub.dev 2026-10-12 |
| `vector_map_tiles*` (rejected) | BSD-3-Clause / MIT | Yes, but stale | pins `flutter_map ^7`, conflicts with our `^8.3.2`; unmaintained since 2024 |
| `pmtiles` CLI 1.31.2 (build tool only) | BSD-3-Clause | Yes | never shipped in the app |
| Protomaps basemap code/schema | BSD-3-Clause / MIT (Tilezen roots) | Yes | style design CC0, icons MIT |
| Tile data (OSM + Natural Earth) | **ODbL** | N/A (data, not code) | see below |
| Our styles (`app/assets/map/*.json`) | CC0, same as project intent | Yes | written from scratch, no third-party style copied |
| Noto Sans (map glyphs) | SIL OFL 1.1 | Yes | separate font asset, like bundled Manrope (OFL) |
| `latlong2` (transitive via `flutter_map`) | **Apache-2.0** | **No (pre-existing)** | FSF: Apache-2.0 is compatible only with GPLv3. Predates this change; flagged for INFRA-19, not introduced here |
| `flutter_map_tile_caching` | - | - | not used, not needed |

ODbL obligations for the tile file: the `.pmtiles` extract is a
Derivative Database. We distribute it under ODbL terms: keep this file
public alongside the app release, keep the attribution
"© OpenStreetMap contributors" visible on the map (the existing chip,
kept in offline mode), and link the OSM copyright page. Rendered map
images are a Produced Work and need only the attribution. The `.pmtiles`
file itself is **not** GPL code. `flutter_map_tile_caching` was not
used (verified unnecessary).

## 3. Build (one command, reproducible)

Prerequisite: `pmtiles` CLI 1.31.2, either on PATH or via `PMTILES_BIN`:

```sh
curl -sSfLO https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz
tar xzf go-pmtiles_1.31.2_Linux_x86_64.tar.gz pmtiles
sudo install pmtiles /usr/local/bin/pmtiles
pmtiles version  # must print 1.31.2
```

Pick the asset matching your machine (`uname -sm` to check). The
`Linux_x86_64` file above is only for 64-bit Intel/AMD Linux:

| Machine | Asset |
| ------- | ----- |
| Linux, Intel/AMD 64-bit | `go-pmtiles_1.31.2_Linux_x86_64.tar.gz` |
| Linux, ARM 64-bit (Raspberry Pi, Oracle Ampere, Apple VM) | `go-pmtiles_1.31.2_Linux_arm64.tar.gz` |
| macOS, Apple Silicon | `go-pmtiles_1.31.2_Darwin_arm64.zip` |
| macOS, Intel | `go-pmtiles_1.31.2_Darwin_x86_64.zip` |
| Windows 64-bit | `go-pmtiles_1.31.2_Windows_x86_64.zip` |

`exec format error` (or `Syntax error: ")" unexpected`) after install
means the wrong asset: the file is not executable on your CPU/OS. Check
with `file $(which pmtiles)`. A common slip is installing the archive
itself instead of the extracted `pmtiles` binary, or an HTML error page
from a failed download (re-run `curl` with the `-f` flag so HTTP errors
fail loudly, and confirm the file starts with the `ELF` or `Mach-O`
magic via `file`).

Without the binary the tasks fail with install help (exit 1), never a
stack trace. `map-extract` and `map-verify` run the binary you name via
`PMTILES_BIN` or PATH, so they carry broad `--allow-run` plus full
`--allow-read` (input/output paths are maintainer-chosen); `map-bbox`
and `map-test` stay fully scoped and never spawn anything.
The extract reads byte ranges from the Protomaps daily planet build (a
data file, not a tile endpoint), so no bulk tile download is involved.

```sh
# from tools/
deno task map-bbox     # coverage check: municipality + app bounds + routes
deno task map-extract  # builds sao_mateus.pmtiles (~21 s, ~46 MB transfer)
deno task map-verify   # pmtiles verify + header + size report
```

Pinned inputs live in `tools/map/bbox.json`: Protomaps build `20261019`,
extract bbox `-40.46,-19.20,-39.50,-18.39` (municipality relation
1834958 plus buffer, extended east to cover the app pan bounds over
Guriri waters). Bump the build date for a refresh; the bbox changes only
if the municipality boundary or the app bounds change.

Glyphs (one-time, then committed): generate PBF glyphs from Noto Sans
Regular (OFL) for the `fonts/{fontstack}/{range}.pbf` path the styles
reference. VERIFY the exact `font-maker` invocation at build time; output
goes next to the tiles on the static host (`maps/fonts/`), never to a
third-party host.

## 4. Update routine (OSM data changes)

1. Pick the new daily build date from `https://maps.protomaps.com/builds/`.
2. Set `protomaps_build` in `tools/map/bbox.json`.
3. Run the three commands above; confirm `map-bbox` passes (it fails when
   any committed route trace leaves the bbox) and note the printed size.
4. Deploy the file to the static host (section 5) and record the build
   date plus size in `DECISIONS.md`.

## 5. Hosting and runtime

- File: `sao_mateus.pmtiles`, 41.6 MB at z0-15 (measured 2026-10-20).
  CI builds it on every static deploy (`deploy-static.yml`: installs
  pmtiles 1.31.2, runs `map-bbox`, `map-extract`, `map-verify`) and
  publishes it at `maps/sao_mateus.pmtiles`. Never commit the file to
  git (`*.pmtiles` is gitignored); a local `deno task map-extract` is
  for verification and size checks only. The pinned daily build is
  hotlinked and must be refreshed within Protomaps' retention window;
  see D75.
- Web: serve from our Pages host at `maps/sao_mateus.pmtiles`, read with
  HTTP range requests so the browser fetches only needed chunks. Verify
  ranges work after deploy: `curl -s -r 0-100 -o /dev/null -w "%{http_code}" \
  https://<static>/maps/sao_mateus.pmtiles` must print `206`. If it does
  not, the client falls back to a one-time full download with progress
  (documented graceful path), and ranges stay VERIFY.
- Android: fully offline. The file is NOT bundled in the APK (41.6 MB
  would break the 15 MB RNF14 budget); it is fetched once from our own
  host on first map use and stored in app storage (native renderers need
  a file path, never a flutter asset). Missing or corrupt file falls back
  to the current OSM raster path with the same attribution.
- Styles: `app/assets/map/protomaps-light.json` /
  `protomaps-dark.json` (MapLibre v8, Protomaps v4 schema only). No
  sprites; glyphs resolve relative to the style location on our host.
  Labels use `coalesce(name:pt, name)`; `name:pt` presence is VERIFY at
  render test (probed z14 centro tile contains `name:pt`; Guriri tile has
  `name` only, so the fallback matters).
- Config seam: `app/lib/features/map/offline_map.dart`
  (`mapStyleAssetFor`, `resolvePmtilesUrl`, `substitutePmtilesUrl`,
  `styleHasNoThirdPartyHosts`, the last enforced by test).
- Renderer: proposed `maplibre_gl` (D40), NOT yet added. It needs its own
  ADR with APK size delta, merged-manifest audit and a low-end device
  render test, plus owner approval for the new dependency.

## 6. Measurements (z0-15 measured 2026-10-20; other rows 2026-10-12 unless noted)

| Item | Value |
| ---- | ----- |
| PMTiles z0-15 (shipped range) | **41.6 MB** (46 MB transferred, overfetch 0.05, 77 requests, ~21 s) |
| z0-14 / z0-13 / z0-12 variants | 28.1 / 17.8 / 10.6 MB (2026-10-12 build; not re-measured) |
| Tile probe, centro z14 (36.6 KB decoded) | roads, places, `name`, `name:pt` present |
| Tile probe, Guriri z14 (2.1 KB decoded) | roads + `name` present, covered |
| Municipality + app bounds + routes coverage | pass (`deno task map-bbox`) |
| APK size delta | ~10 KB (styles + config only; tiles not bundled, no new dep) |
| Web transfer on first map view | styles ~2x5 KB + tile byte ranges only (renderer pending) |
| Time to first render, memory, low-end fps | NOT measured: no renderer wired yet, no device on this host |
| `flutter analyze` / tests | clean; 6 new client tests, 2 new tool tests pass |

Zoom choice: keep tiles at z0-15 (matches the planet build, no rebuild
needed) and overzoom vector data to the app maxZoom 17. Geometry stays
sharp; only detail density stops increasing past 15, which is correct
for bus tracking (street names and stop context are present at 14-15).

## 7. Raster fallback (evaluated, not chosen)

Pre-rendered raster light+dark sets for the same bbox at z12-16 would be
roughly 37k tiles per theme (~28k at z16 alone), i.e. hundreds of MB per
theme at typical PNG sizes, times two for both themes, versus one 41.6 MB
vector file serving both themes. Raster also needs a tile server or a
bulk prefetch (against OSM policy when self-rendered infra is absent),
while vector range reads stay lazy. Verdict: vector wins by an order of
magnitude on size and offline simplicity; revisit only if vector render
proves too slow on the PLAN 3.3 low-end phones during the D40 renderer
test (record fps/PSS then).

## 8. Privacy and failure behavior

- Zero runtime requests to third-party tile, font or sprite hosts:
  enforced by `offline_map_test.dart` (`styleHasNoThirdPartyHosts` over
  the real style files) plus a pre-release network-inspection checklist
  (airplane-mode Android, clean-cache web with a request log).
- Tested: offline Android shows the bundled path or the raster fallback;
  theme switching swaps the style asset; corrupt/missing file falls back
  without crashing (renderer task must add widget tests for these).
- Attribution stays visible in every mode: "© OpenStreetMap
  contributors" chip linking to the OSM copyright page.

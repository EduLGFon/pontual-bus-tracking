# VERIFY-NOTES.md - UI_SPEC.md verification results

Research subagent findings for the VERIFY items in `docs/ui/UI_SPEC.md`.

Verified on 2026-10-10 against the toolchain installed on this machine: Flutter 3.47.6 (stable, revision 5fc346839b, 2026-09-30), Dart 3.13.5, and the package versions pinned in `app/pubspec.yaml`. Paths below are relative to the pub cache root `~/.pub-cache/hosted/pub.dev/` and the Flutter SDK root `/home/edubot/flutter`.

## 1. flutter_map 8.3.2 (dashed polyline, camera, layering)

- `StrokePattern` exists with a `dashed` named constructor: `const StrokePattern.dashed({required List<double> segments, PatternFit patternFit = PatternFit.scaleUp})`, `segments` even length >= 2, alternating dash/gap in px. `Polyline` exposes `pattern` (default solid). Use `StrokePattern.dashed(segments: <double>[14, 8])` for the 4 dp predicted path.
- `MapOptions.onPositionChanged` is `PositionCallback? = void Function(MapPosition position, bool hasGesture)`.
- `MapController.fitCamera(CameraFit cameraFit)` returns bool; `CameraFit.bounds({required LatLngBounds bounds, EdgeInsets padding, double? maxZoom, double minZoom, bool forceIntegerZoomLevel})`, plus `coordinates` and `insideBounds` variants. Call only on settle, never per frame.
- Layering is plain `Stack` order: put `TileLayer`, then `Positioned.fill(ColoredBox(color: mapScrim))`, then `PolylineLayer`, then `MarkerLayer`, then attribution. The scrim must be `Positioned.fill`; it does not swallow taps.
- `TileLayer` constructor (flutter_map 8.3.2): `urlTemplate`, `minZoom`, `maxZoom`, `minNativeZoom`, `maxNativeZoom`, `tileProvider`, `userAgentPackageName`, `tileDisplay`, etc. `MapOptions.keepAlive` keeps the camera when the map lives in a scrolling parent.
- Two separate `Polyline`s in the same `PolylineLayer` (8 dp casing in `bg` under the 5 dp line colour) is the supported casing pattern; `borderStrokeWidth`/`borderColor` cannot express per-polyline casing order.

## 2. Deferred imports on Flutter web

- `import 'x.dart' deferred as map;` plus `await map.loadLibrary();` is a current Dart language feature, not deprecated, implemented by both dart2js and dart2wasm in SDK 3.13.5. Authoritative sources: dart.dev/language/libraries ("Lazily loading a library"), flutter.dev blog on optimizing web performance, local SDK source (`js_helper.dart` `loadDeferredLibrary`, `deferred_patch.dart` `loadLibraryFromLoadId`).
- Caveats: a deferred library's constants are not constants in the importing file; types from a deferred library cannot be used in the importing file (move argument types into a shared non-deferred library); `loadLibrary()` is idempotent.
- Practical: web-only size win; on Android the same import compiles to a normal import, so guard the deferred branch behind `kIsWeb` if you want to avoid the `FutureBuilder` indirection on native. Keep the whole map subtree in one file so it becomes a single chunk.
- `flutter build web --analyze-size` does NOT exist in 3.47.6 (confirmed by running the command). Use `du -b build/web/*.js build/web/*.part.js` or `flutter build web --dump-info`.
- UI_SPEC 8 mentions `flutter-first-frame`. The event name was not verified as part of this task and should be checked against `engine/src/flutter/lib/web_ui/` before use. **UNVERIFIED.**

## 3. Variable fonts and `FontFeature.tabularFigures`

- `FontVariation` is declared in `dart:ui`: `const FontVariation(this.axis, this.value)` with axis length 4 and value range -32768..32768; named constructors `italic`, `opticalSize`, `slant`, `width`, `weight` (axis `wght`, value 1..1000). `FontVariation('wght', 800)` and `FontVariation.weight(800)` are both valid.
- `TextStyle.fontVariations` is `List<FontVariation>?`. `FontFeature.tabularFigures()` exists (`feature = 'tnum', value = 1`), quoted from the installed SDK; same declaration in the web SDK.
- `fontVariations` works on native (Android, Impeller text path via Skia), CanvasKit and Skwasm: the engine converts the requested weight into a `wght` variation coordinate and forwards user variations.
- Single variable TTF registered in pubspec `fonts:`: on native builds the pubspec `weight:` key is currently ignored (engine `font_collection.cc` has `// TODO(chinmaygarde): Handle weights and styles.`), so the variation axis drives the weight. Register the font once and let `fontWeight`/`fontVariations` pick the weight.
- **UNVERIFIED by execution:** the actual rendered stroke weight at runtime needs a device or a golden test with the real subset font.

## 4. geolocator 14.1.1 API

- Static methods on `Geolocator`: `checkPermission`, `requestPermission`, `isLocationServiceEnabled`, `openAppSettings`, `openLocationSettings`, `getServiceStatusStream`, `getLastKnownPosition`, `getCurrentPosition` (with `LocationSettings? locationSettings`; avoid the deprecated `desiredAccuracy`/`forceAndroidLocationManager`/`timeLimit` params), `getPositionStream`, `getLocationAccuracy`, `requestTemporaryFullAccuracy`, `distanceBetween`, `bearingBetween`.
- `LocationPermission` enum: `denied`, `deniedForever`, `whileInUse`, `always`, `unableToDetermine`. Never request `always` (`ACCESS_BACKGROUND_LOCATION` is a hard project limit). "Permanently denied" branch is `deniedForever`. `unableToDetermine` is web-only for browsers without the Permission API.
- No permission-change stream exists; use `AppLifecycleState.resumed` and re-check with `checkPermission()`. `getServiceStatusStream()` throws synchronously on web; guard with `!kIsWeb`.
- `openAppSettings`/`openLocationSettings` throw synchronously on web (geolocator_web). On web it is impossible to open OS settings from the app; show browser address-bar instructions plus a "Já permiti, tentar de novo" button that calls `checkPermission()`. Guard both calls with `!kIsWeb` and try/catch. On Android they return a bool.
- `permission_handler` is already present in `app/pubspec.yaml` (`permission_handler: ^12.0.0`), approved by ADR 2026-10-10 for the Android 13+ notification permission. Its role is notifications only; location stays with geolocator.

## 5. `--analyze-size` for apk and web

- `flutter build apk --analyze-size`: EXISTS. Flag only on release builds; requires a single ABI via `--target-platform`. Exact syntax: `flutter build apk --analyze-size --target-platform android-arm64 --release`.
- `flutter build web --analyze-size`: DOES NOT EXIST in 3.47.6 (confirmed by running the command). For web use `du -b build/web/*.js build/web/*.part.js` or `flutter build web --dump-info`.
- Web renderer flag changed: `--web-renderer` no longer exists. Renderer is selected by dart defines or the `--wasm` flag. Default for a JS build is CanvasKit; default for a `--wasm` build is Skwasm. Combining `--wasm` with an explicit renderer dart define is a tool exit.

## 6. OpenStreetMap tile usage policy (tile.openstreetmap.org)

Source: https://operations.osmfoundation.org/policies/tiles/ (retrieved 2026-10-10).

Requirements (quoted): use the correct HTTPS URL; provide visible licence attribution; send a valid HTTP User-Agent that clearly identifies the application (or a platform `X-Requested-With` app ID where set automatically); from web pages ensure a valid HTTP Referer header; cache tiles locally according to HTTP caching headers (or at least 7 days if the cache cannot read them); avoid encouraging or enabling copyright infringement.

Must not: bulk download ("scrape") tiles or offer prefetch features; send `Cache-Control: no-cache`, `Pragma: no-cache` or similar no-cache headers by default; set a restrictive Referrer-Policy that prevents the HTTP Referer header being sent; use the HTTP URL (use HTTPS); masquerade as another app's User-Agent or rely on a library's default User-Agent.

On identification: send a clear, unique User-Agent string that names the app and optionally includes a contact URL or email. Traffic using library defaults will be blocked.

On caching: do not bypass caches; honour server caching headers (`Cache-Control`, `Expires`, `Etag`); if the cache cannot read them, cache each tile for at least 7 days.

On bulk download: any pre-emptive fetching of tiles other than those a user is actively viewing, including pre-seeding large areas or multiple zoom levels in advance, building tile archives, automated scans across wide bounding boxes (especially at high zoom z>=14), headless bots that pan/zoom the map to force rendering. Offline use is not permitted on tile.openstreetmap.org. Permitted: normal interactive viewing by a human where the client requests only the tiles needed for the current viewport (with modest, short-range look-ahead typical of browsers).

What this means for this repo:

- User-Agent on native: `TileLayer.userAgentPackageName` is the hook. flutter_map injects `'flutter_map ($userAgentPackageName)'` only when `!kIsWeb`. Because the policy forbids relying on a library default, override the header with an app-specific string via the tile provider (`'User-Agent': 'Pontual/1.0 (+https://edubot.github.io/pontual-bus-tracking)'`). `userAgentPackageName: 'br.com.pontual.app'`.
- User-Agent on web is not settable (flutter_map docs state the browser limitation); the OSM policy accepts this ("Browsers will use the browser's default User-Agent"). For web the requirements to satisfy are the Referer header and the HTTP Referrer-Policy: do not set a restrictive `referrer` meta tag or header. Flutter's generated `web/index.html` does not set one by default; verify nothing adds one before release.
- Caching: the default `NetworkTileProvider()` uses a session-only in-memory cache plus flutter_map's `BuiltInMapCachingProvider` on native (PLAN.md D12 relies on the ">= 8.2.0 built-in cache", which matches this version). The built-in provider honours HTTP headers ("Usually uses HTTP headers to determine tile freshness"). The policy's 7-day floor is satisfied by that path. The cache is not an offline feature: it is a repeat-view cache only. The project hard limit "never bulk-download or prefetch OSM tiles" already matches the policy's section 4.
- Attribution is mandatory and must be visible. The UI_SPEC attribution chip (top-right, tappable to the OSM copyright page) satisfies this. Keep it on screen at all times, including when the sheet is at `full` and in both themes.
- Data saver: with `dataSaver` on, the map stays collapsed until requested (UI_SPEC 7.8), which also keeps tile requests low. Correct under the policy; no extra work.
- Attribution/exit plan: the policy warns access "may be blocked without prior notice" and recommends an alternative for heavy use. PLAN.md R-05 and D12 already record the `TileSource` exit plan.

Unverified items:

- The actual tile cache size cap (PLAN.md S3 mentions "~50 MB"): the `BuiltInMapCachingProvider` default in the installed 8.3.2 is `maxCacheSize = 1_000_000_000` (1 GB), and the project must set a smaller cap explicitly. The 50 MB figure is not yet wired; needs an ADR or a config value.
- Whether the OSM servers send `Cache-Control` that maps to >= 7 days was not tested (no network probes were made against the production tile server, per the project rule about not running load tests). The code path honours server headers, which is what the policy requires.

## Summary of VERIFY answers

| # | Item | Result |
|---|---|---|
| 1 | `StrokePattern.dashed` in flutter_map 8.3.2 | Supported, `required List<double> segments`, even length >= 2 |
| 1 | `MapOptions.onPositionChanged` | `PositionCallback? = void Function(MapPosition, bool)` |
| 1 | `MapController.fitCamera` / `CameraFit.bounds` | Supported, quoted in 1.3 |
| 1 | Widget between `TileLayer` and `MarkerLayer` | Supported, plain `Stack` child order |
| 2 | Deferred imports + `loadLibrary` on web | Supported, not deprecated, both dart2js and dart2wasm |
| 3 | `FontVariation('wght', 800)` and `FontFeature.tabularFigures()` | Both exist and work on native, CanvasKit, Skwasm |
| 3 | Single variable TTF + heavier `fontWeight` | Native ignores pubspec `weight:`, weight comes from the `wght` axis |
| 4 | geolocator API and `LocationPermission` | Quoted in 4.1 and 4.2 |
| 4 | Permission-change listener | Does not exist; use `AppLifecycleState.resumed` |
| 5 | `--analyze-size` on apk | Exists |
| 5 | `--analyze-size` on web | Does not exist (confirmed by running the command) |
| 6 | OSM tile policy | Quoted; UA, caching, no-bulk-download and attribution confirmed |

## Open verification items

- `flutter build web --analyze-size` does not exist in 3.47.6; UI_SPEC 11.4 must be corrected to use `du` on `build/web` (plus `flutter build apk --analyze-size` for Android).
- `flutter-first-frame` event name in UI_SPEC 8: not verified; check against `engine/src/flutter/lib/web_ui/` before use.
- Actual rendered stroke weight of the variable font at runtime: needs a device or golden test (UNVERIFIED by execution).
- Tile cache size cap: the `BuiltInMapCachingProvider` default is 1 GB; the project must set a smaller cap explicitly (50 MB figure not wired).
- Whether OSM servers send `Cache-Control` mapping to >= 7 days: not tested (no network probes). Code path honours server headers.
- No ADR recorded in `DECISIONS.md` yet for the bundled font choice (gap 1).
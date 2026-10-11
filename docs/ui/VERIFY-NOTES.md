# VERIFY-NOTES.md - UI_SPEC.md verification results

Research subagent findings for the VERIFY items in `docs/ui/UI_SPEC.md`.

Verified on 2026-10-10 against the toolchain installed on this machine:
Flutter 3.47.6 (stable, revision 5fc346839b, 2026-09-30), Dart 3.13.5,
and the package versions pinned in `app/pubspec.yaml`.

Paths below are given relative to the pub cache root
`~/.pub-cache/hosted/pub.dev/` and the Flutter SDK root `/home/edubot/flutter`.

## 1. flutter_map 8.3.2 dashed polyline, camera and layering API

### 1.1 Dashed polylines: YES

`StrokePattern` exists with a `dashed` named constructor. Source:
`flutter_map-8.3.2/lib/src/layer/shared/line_patterns/stroke_pattern.dart`.

```dart
@immutable
class StrokePattern {
  const StrokePattern.solid();
  const StrokePattern.dotted({
    double this.spacingFactor = 1.5,
    PatternFit this.patternFit = PatternFit.scaleUp,
  });

  /// Elongated dashes, with length and spacing set by [segments].
  const StrokePattern.dashed({
    required List<double> this.segments,
    PatternFit this.patternFit = PatternFit.scaleUp,
  })  : assert(segments.length >= 2, '`segments` must contain at least two items'),
        assert(segments.length % 2 == 0, '`segments` must have an even length'),
        spacingFactor = null;

  final double? spacingFactor;
  final List<double>? segments; // [a1, b1, (a2, b2, ...)] dash, gap, in px
  final PatternFit? patternFit; // default PatternFit.scaleUp
}
```

Required field: `segments`, a non-empty list of even length (minimum two
items), alternating dash length and gap length in pixels. `[50, 10]` gives a
50 px dash and a 10 px gap. Values must be strictly positive per the doc
comment. `patternFit` defaults to `PatternFit.scaleUp` (alternatives:
`none`, `scaleDown`, `scaleUp`, `appendDot`, `extendFinalDash`).

`Polyline` exposes it directly. Source:
`flutter_map-8.3.2/lib/src/layer/polyline_layer/polyline.dart`.

```dart
class Polyline<R extends Object> with HitDetectableElement<R> {
  final List<LatLng> points;
  final double strokeWidth;
  final StrokePattern pattern; // default const StrokePattern.solid()
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
  final List<Color>? gradientColors;
  final List<double>? colorsStop;
  final StrokeCap strokeCap; // default StrokeCap.round
  final StrokeJoin strokeJoin; // default StrokeJoin.round
  final bool useStrokeWidthInMeter;
  final R? hitValue;

  Polyline({
    required this.points,
    this.strokeWidth = 1.0,
    this.pattern = const StrokePattern.solid(),
    this.color = const Color(0xFF00FF00),
    this.borderStrokeWidth = 0.0,
    this.borderColor = const Color(0xFFFFFF00),
    this.gradientColors,
    this.colorsStop,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.useStrokeWidthInMeter = false,
    this.hitValue,
  });
}
```

The same class is exported from `package:flutter_map/flutter_map.dart`
(`export '.../shared/line_patterns/stroke_pattern.dart';`). `Polygon` has an
identical `pattern` field.

Code the UI_SPEC map layer should use for the 4 dp predicted path:

```dart
Polyline(
  points: predictedPoints,
  strokeWidth: 4,
  color: predictedColor,
  pattern: const StrokePattern.dashed(segments: <double>[14, 8]),
  strokeCap: StrokeCap.round,
  strokeJoin: StrokeJoin.round,
)
```

Note for the route polyline in UI_SPEC 7.5: two separate `Polyline`s in the
same `PolylineLayer` (8 dp casing in `bg` under the 5 dp line colour) is the
supported pattern; the border fields (`borderStrokeWidth`, `borderColor`) are a
single-polyline alternative and cannot express per-polyline casing order.

### 1.2 MapOptions.onPositionChanged signature

Source: `flutter_map-8.3.2/lib/src/misc/position.dart` (line 44) and
`flutter_map-8.3.2/lib/src/map/options/options.dart` (line 130).

```dart
typedef PositionCallback = void Function(MapPosition position, bool hasGesture);
```

```dart
// MapOptions field
final PositionCallback? onPositionChanged;
```

So the callback is invoked as `onPositionChanged(position, hasGesture)`.
`MapPosition` carries `center`, `bounds`, `zoom`. It is a regular constructor
parameter of `MapOptions` (not a late field), so it is cheap to rebuild.

### 1.3 MapController.fitCamera and CameraFit.bounds

Source: `flutter_map-8.3.2/lib/src/map/controller/map_controller.dart`
(line 126) and `flutter_map-8.3.2/lib/src/map/camera/camera_fit.dart`.

```dart
abstract class MapController {
  /// Returns false if the camera was not moved or if animation was not
  /// started because the map is not ready yet.
  bool fitCamera(CameraFit cameraFit);

  bool move(
    LatLng center, {
    double? zoom,
    Offset offset = Offset.zero,
    Offset? offsetOrigin,
    String? id,
    Duration? duration,
    Curve? curve,
  });
}
```

```dart
@immutable
abstract class CameraFit {
  const CameraFit();

  const factory CameraFit.bounds({
    required LatLngBounds bounds,
    EdgeInsets padding,
    double? maxZoom,
    double minZoom,
    bool forceIntegerZoomLevel,
  }) = FitBounds._;

  const factory CameraFit.insideBounds({ /* same params */ }) = FitInsideBounds._;
  const factory CameraFit.coordinates({
    required List<LatLng> coordinates,
    EdgeInsets padding,
    double? maxZoom,
    double minZoom,
    bool forceIntegerZoomLevel,
  }) = FitCoordinates._;

  MapCamera fit(MapCamera camera);
}
```

Concrete classes: `FitBounds` (the camera fits *inside* the bounds, with a zoom
cap), `FitInsideBounds`, `FitCoordinates`. `CameraFit.bounds` and
`CameraFit.coordinates` are the two useful ones for the line screen.
`padding` defaults to `EdgeInsets.zero`, `minZoom` to 0, `maxZoom` to null.
`bounds` is a `LatLngBounds` from `package:latlong2`.

Call the fit "only on settle, never per frame" as the UI_SPEC says:
`_mapController.fitCamera(CameraFit.bounds(bounds: b, padding: EdgeInsets.fromLTRB(16, 16, 16, sheetHeight)))`.
`fitCamera` returns `false` if the map is not ready, so guard calls with
`if (mounted)`.

### 1.4 PolylineLayer, layer order and a scrim widget between layers

```dart
base class PolylineLayer<R extends Object> {
  final List<Polyline<R>> polylines;
  final double? cullingMargin; // default 10
  final LayerHitNotifier<R>? hitNotifier;
  final double minimumHitbox; // default 10
  final bool drawInSingleWorld;

  const PolylineLayer({
    super.key,
    required this.polylines,
    this.cullingMargin = 10,
    this.hitNotifier,
    this.minimumHitbox = 10,
    this.drawInSingleWorld = false,
    super.simplificationTolerance,
  });
}
```

Layering is plain `Stack` order: `FlutterMap` builds
`ClipRect(child: Stack(children: [Positioned.fill(ColoredBox(backgroundColor)), ...children]))`.
Every `FlutterMap.children` entry is painted in list order, so putting
`TileLayer`, then a `ColoredBox`, then `PolylineLayer`, then `MarkerLayer`
gives exactly the requested scrim between tiles and markers. Source:
`flutter_map-8.3.2/lib/src/map/widget.dart`.

```dart
// ColoredBox-style scrim between the tile layer and the marker layer.
FlutterMap(
  mapController: controller,
  options: MapOptions(...),
  children: <Widget>[
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'br.com.pontual.app',
      minZoom: 12,
      maxNativeZoom: 17,
      tileProvider: NetworkTileProvider(silenceExceptions: false),
    ),
    Positioned.fill(
      child: ColoredBox(color: colors.mapScrim), // no ColorFiltered, no blend
    ),
    PolylineLayer(polylines: <Polyline>[routeCasing, routeLine]),
    MarkerLayer(markers: vehicleMarkers),
    const RichAttributionWidget(
      attributions: <SourceAttribution>[
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        ),
      ],
      popupBackgroundColor: Color(0xFFF6F5F1),
    ),
  ],
)
```

Caveats for the scrim widget:
- It must be `Positioned.fill` (or `Align`) because the stack children are not
  stretched by default, matching the package's own guidance that non-`MobileLayerTransformer`
  children are "static" and should position themselves.
- `mapScrim` is a translucent colour, so it is drawn with a single alpha layer
  and does not defeat `MobileLayerTransformer` (it has no transform to lose).
- The map stays interactive underneath, because `ColoredBox` has no gesture
  behaviour; pointer events fall through to the layers. If a future scrim ever
  swallows taps, wrap it in `AbsorbPointer` or use `IgnorePointer`.

Note that the 8 dp casing / 5 dp line pattern does NOT use
`Polyline.borderStrokeWidth`. Two `Polyline` entries in list order are the
supported way to get a casing under a line.

### 1.5 Related API the UI_SPEC map layer needs

```dart
// TileLayer constructor (flutter_map-8.3.2/lib/src/layer/tile_layer/tile_layer.dart)
TileLayer({
  String? urlTemplate,
  String? fallbackUrl,
  @Deprecated('`tileSize` is deprecated. Use `tileDimension` instead.') double? tileSize,
  int tileDimension = 256,
  double minZoom = 0,
  double maxZoom = double.infinity,
  int minNativeZoom = 0,
  int maxNativeZoom = 19,
  bool zoomReverse = false,
  double zoomOffset = 0.0,
  Map<String, String> additionalOptions = const {},
  List<String> subdomains = const ['a', 'b', 'c'],
  int keepBuffer = 2,
  int panBuffer = 1,
  ImageProvider? errorImage,
  TileProvider? tileProvider, // default NetworkTileProvider()
  bool tms = false,
  WMSTileLayerOptions? wmsOptions,
  TileDisplay tileDisplay = const TileDisplay.fadeIn(),
  bool? retinaMode,
  TileErrorEvictCallback? errorTileCallback,
  TileBuilder? tileBuilder,
  EvictErrorTileStrategy evictErrorTileStrategy = EvictErrorTileStrategy.none,
  TileReset? reset,
  TileBounds? tileBounds,
  TileUpdateTransformer? tileUpdateTransformer,
  String userAgentPackageName = 'unknown',
})
```

`MapOptions` initial state, for the "fit on enter" rule (source:
`lib/src/map/options/options.dart`):

```dart
const MapOptions({
  Crs crs = const Epsg3857(),
  LatLng initialCenter = const LatLng(50.5, 30.51),
  double initialZoom = 13.0,
  double initialRotation = 0.0,
  CameraFit? initialCameraFit,
  CameraConstraint cameraConstraint = const CameraConstraint.unconstrained(),
  InteractionOptions interactionOptions = const InteractionOptions(),
  double? minZoom,
  double? maxZoom,
  Color backgroundColor = const Color(0xFFE0E0E0),
  GestureTapCallback? onTap,
  ...
  PositionCallback? onPositionChanged,
  MapEventCallback? onMapEvent,
  VoidCallback? onMapReady,
  bool keepAlive = false,
})
```

`MapOptions.keepAlive` is the flag to set when the map lives inside a
`DraggableScrollableSheet` or a scrolling parent, so the camera is not reset.

## 2. Deferred imports on Flutter web

### 2.1 Answer: still supported, not deprecated

`import 'x.dart' deferred as map;` plus `await map.loadLibrary();` is a
current Dart language feature, not deprecated, and it is implemented by both
dart2js and dart2wasm in the installed SDK 3.13.5.

Authoritative sources:
- https://dart.dev/language/libraries (section "Lazily loading a library").
  Current page states: "To lazily load a library, first import it using
  `deferred as`. ... When you need the library, invoke `loadLibrary()` using
  the library's identifier. ... You can invoke `loadLibrary()` multiple times
  on a library without problems. The library is loaded only once." The same
  page adds the two caveats quoted in 2.3.
- https://flutter.dev/blog/optimizing-performance-in-flutter-web-apps-with-tree-shaking-and-deferred-loading
- Local SDK source proving both compilers implement it:
  `/home/edubot/flutter/bin/cache/dart-sdk/lib/_internal/js_runtime/lib/js_helper.dart`,
  function `loadDeferredLibrary`, with the comment "Loads a deferred library.
  The compiler generates a call to this method to implement
  `import.loadLibrary()`."
  `/home/edubot/flutter/bin/cache/dart-sdk/lib/_internal/wasm/js_common/deferred_patch.dart`,
  function `loadLibraryFromLoadId`, which resolves through
  `moduleLoadingHelper.loadDeferredId`, thrown as `DeferredLoadException` on
  failure.
- No `@Deprecated` annotation on `loadLibrary`: grepping the installed SDK for
  "deprecated" in the deferred-loading patches returns nothing.

### 2.2 Recommended pattern for this project

`main.dart` keeps the deferred library private behind a facade, so no type
from the deferred library crosses the boundary and the map can be tree-shaken
out of the initial bundle:

```dart
// lib/ui/features/line/map/map_library.dart
import 'package:flutter/material.dart' show Widget;
import 'map_entry.dart' deferred as map; // the deferred library

/// Loads the map code and builds the map widget.
Future<Widget> loadLineMap(LineMapArgs args) async {
  await map.loadLibrary();
  return map.LineMap(args);
}
```

```dart
// UI_SPEC 7.5 map host, inside a FutureBuilder
FutureBuilder<Widget>(
  future: _mapFuture ??= loadLineMap(args), // cache the future
  builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const _MapPlaceholder(); // bg colour + badge + "Carregando mapa"
    }
    if (snapshot.hasError) return const _MapError();
    return snapshot.data!;
  },
)
```

### 2.3 Caveats (documented, not guessed)

From https://dart.dev/language/libraries:

- "A deferred library's constants aren't constants in the importing file.
  Remember, these constants don't exist until the deferred library is loaded."
  So `const map.SomeWidget(...)` in the importing file is a compile error; build
  the instance with the plain constructor after `await`.
- "You can't use types from a deferred library in the importing file." Move the
  argument type (`LineMapArgs` in the sketch above) into a shared, non-deferred
  library imported by both sides.
- `loadLibrary()` may be called repeatedly; it is idempotent and returns the
  same `Future`.

Practical notes for this repo:
- Deferred loading is a dart2js/dart2wasm feature, so it is a web-only size
  win. On Android the same import compiles to a normal (lazily loaded by the
  VM) import, so guard the deferred branch behind `kIsWeb` and import normally
  on native if you want to avoid the `FutureBuilder` indirection there.
- Only one deferred chunk per library. Keep the whole map subtree (map widget,
  markers, painters, the `TileSource` wrapper) in one file so it becomes a
  single `main.dart.js_1.part.js` chunk.

### 2.4 Corollary VERIFY items found while checking this

- `flutter build web --analyze-size` does NOT exist in 3.47.6, so there is no
  CLI flag that reports the chunk sizes. Verify the split by listing
  `build/web/main.dart.js_1.part.js` in the output directory, or with the
  `--dump-info` option (`flutter build web --dump-info`, which passes
  `--stage=dump-info-all` to dart2js) if a per-symbol breakdown is needed.
- UI_SPEC 8 mentions `flutter-first-frame`. The event name was not verified as
  part of this task and should be checked against
  `engine/src/flutter/lib/web_ui/` before use; the Flutter docs for web
  initialization (docs.flutter.dev/platform-integration/web/initialization)
  are the reference. **UNVERIFIED.**

## 3. Variable fonts and FontFeature.tabularFigures

### 3.1 Exact API (quoted from the installed SDK)

`FontVariation` is declared in `dart:ui`. Installed copies:

- `/home/edubot/flutter/bin/cache/pkg/sky_engine/lib/ui/text.dart` (native VM,
  lines 1029 and 1147)
- `/home/edubot/flutter/bin/cache/flutter_web_sdk/lib/ui/text.dart` (web,
  line 144)

```dart
class FontVariation {
  const FontVariation(this.axis, this.value)
    : assert(axis.length == 4, 'Axis tag must be exactly four characters long.'),
      assert(
        value >= -32768.0 && value < 32768.0,
        'Value must be representable as a signed 16.16 fixed-point number, i.e. it must be in this range: -32768.0 <= value < 32768.0',
      );

  const FontVariation.italic(this.value)
      : assert(value >= 0.0),
        assert(value <= 1.0),
        axis = 'ital';

  const FontVariation.opticalSize(this.value)
      : assert(value > 0.0), axis = 'opsz';

  const FontVariation.slant(this.value)
      : assert(value > -90.0),
        assert(value < 90.0),
        axis = 'slnt';

  const FontVariation.width(this.value)
      : assert(value >= 0.0), axis = 'wdth';

  const FontVariation.weight(this.value)
      : assert(value >= 1), assert(value <= 1000), axis = 'wght';

  final String axis;
  final double value;
}
```

`FontVariation('wght', 800)` is therefore valid, and `FontVariation.weight(800)`
is the named equivalent.

`TextStyle.fontVariations` field, quoted from
`/home/edubot/flutter/packages/flutter/lib/src/painting/text_style.dart`
(line 842):

```dart
/// A list of [FontVariation]s that affect how a variable font is rendered.
/// ...
/// ```dart
/// const TextStyle(
///   fontFamily: 'RobotoSlab',
///   fontVariations: <FontVariation>[FontVariation('wght', 900.0)]
/// )
/// ```
final List<FontVariation>? fontVariations;
```

`FontFeature.tabularFigures()` exists. Quoted from
`/home/edubot/flutter/bin/cache/pkg/sky_engine/lib/ui/text.dart` (line 934):

```dart
const FontFeature.tabularFigures() : feature = 'tnum', value = 1;
```

So the UI_SPEC snippet `fontFeatures: [FontFeature.tabularFigures()]` is
correct as written. Same declaration in
`/home/edubot/flutter/bin/cache/flutter_web_sdk/lib/ui/text.dart` (line 934),
so web is covered too.

### 3.2 Does fontVariations work on Android and on web (CanvasKit and Skwasm)?

Yes on all three. Evidence from the engine:

- **Native (Android, Impeller text path via Skia).**
  `/home/edubot/flutter/engine/src/flutter/txt/src/skia/paragraph_builder_skia.cc`
  always converts the requested weight into a `wght` variation coordinate:

  ```cpp
  SkFontArguments::VariationPosition::Coordinate weight_coord{
      GetFourByteTag(kWeightAxisTag), static_cast<float>(txt.font_weight)};
  text_style.setFontArguments(
      SkFontArguments().setVariationDesignPosition({&weight_coord, 1}));
  ```

  and in the per-run overload, user `font_variations` are passed through
  unchanged, with `kWeightAxisTag` appended only if the user did not set a
  `wght` axis themselves. So an explicit `FontVariation('wght', 800)` is
  honoured on Android.
- **CanvasKit (web).**
  `/home/edubot/flutter/engine/src/flutter/lib/web_ui/lib/src/engine/canvaskit/text.dart`
  (lines 92-96) sets the same weight variation axis:

  ```dart
  final int weightValue = fontWeight?.value ?? ui.FontWeight.normal.value;
  final skFontVariation = SkFontVariation();
  skFontVariation.axis = _kWeightAxisTag; // 'wght'
  skFontVariation.value = weightValue.toDouble();
  skTextStyle.fontVariations = <SkFontVariation>[skFontVariation];
  ```
- **Skwasm (web, `--wasm`).**
  `/home/edubot/flutter/engine/src/flutter/lib/web_ui/lib/src/engine/skwasm/skwasm_impl/paragraph.dart`
  (lines 437-450) appends a `wght` `FontVariation` for the requested weight when
  the user has not already supplied one, and forwards the whole list through
  `textStyleSetFontVariations`. The DOM/CSS path used for non-Skia web
  rendering converts the same list via `fontVariationListToCss` in
  `web_ui/lib/src/engine/text/paragraph.dart`.

### 3.3 One variable TTF registered in pubspec `fonts:`, heavier fontWeight requested

**Answer: on native builds the pubspec `weight:` key is currently ignored, so
the variation axis is what actually drives the weight.** This is the important
finding for the "single variable TTF, no per-weight files" plan.

Evidence:
- `/home/edubot/flutter/engine/src/flutter/lib/ui/text/font_collection.cc`
  (line 121) contains the exact comment
  `// TODO(chinmaygarde): Handle weights and styles.`
  immediately above `font_provider->RegisterAsset(...)`. The registered
  `AssetManagerFontStyleSet` (same directory, `asset_manager_font_provider.cc`)
  creates the style from the loaded typeface, not from the manifest key.
- Because every registered face reports the typeface's real style and
  `matchStyleCSS3` is used for matching, requesting `fontWeight: FontWeight.w800`
  against a single-file asset yields the weight through the `wght` variation
  coordinate shown in 3.2, not through a file swap.

Consequences for the app:
- Register the font with one entry and let `fontWeight` / `fontVariations` pick
  the weight. Do not register multiple static weights and expect a file swap on
  native; the file swap behaviour on native is currently limited to style
  (italic) matching and is not driven by the manifest weight key.
- Because the app supports both light and dark and one family, registering the
  same family once is sufficient: `fontFamily: 'Manrope', fontWeight: FontWeight.w800`
  resolves to the `wght=800` instance of the variable font.

**What I could NOT verify:** the actual rendered stroke weight at runtime. The
engine source proves the axis is sent, but confirming the visual result needs a
device or a golden test with the real subset font. **UNVERIFIED by execution.**

## 4. geolocator 14.1.1 API

All signatures below are quoted from the installed package
`~/.pub-cache/hosted/pub.dev/geolocator-14.1.1/lib/geolocator.dart` and
`geolocator_platform_interface-4.4.0`.

### 4.1 Static methods on `Geolocator`

```dart
static Future<LocationPermission> checkPermission();
static Future<LocationPermission> requestPermission();
static Future<bool> isLocationServiceEnabled();
static Future<bool> openAppSettings();
static Future<bool> openLocationSettings();
static Stream<ServiceStatus> getServiceStatusStream();
static Future<Position?> getLastKnownPosition({bool forceAndroidLocationManager = false});
static Future<Position> getCurrentPosition({
  LocationSettings? locationSettings,
  @Deprecated("use settings parameter with AndroidSettings, AppleSettings, WebSettings, or LocationSettings")
  LocationAccuracy desiredAccuracy = LocationAccuracy.best,
  @Deprecated("use settings parameter with AndroidSettings, AppleSettings, WebSettings, or LocationSettings")
  bool forceAndroidLocationManager = false,
  @Deprecated("use settings parameter with AndroidSettings, AppleSettings, WebSettings, or LocationSettings")
  Duration? timeLimit,
});
static Stream<Position> getPositionStream({LocationSettings? locationSettings});
static Future<LocationAccuracyStatus> getLocationAccuracy();
static Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({required String purposeKey});
static double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude);
static double bearingBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude);
```

`requestPermission()` is the current, non-deprecated entry point. The three
deprecated parameters of `getCurrentPosition` (`desiredAccuracy`,
`forceAndroidLocationManager`, `timeLimit`) are the ones the project must
avoid.

### 4.2 LocationPermission enum values (exact)

`geolocator_platform_interface-4.4.0/lib/src/enums/location_permission.dart`:

```dart
enum LocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always,
  unableToDetermine,
}
```

Five values. `whileInUse` and `always` are separate values, which matters
because the project must never request `always` (`ACCESS_BACKGROUND_LOCATION`
is a hard project limit). The "permanently denied" branch in the UI matrix is
`LocationPermission.deniedForever`. `unableToDetermine` is documented as
"only returned by the `Geolocator.checkPermission()` method on the web
platform for browsers that did not implement the Permission API".

### 4.3 Permission-change listener: NONE for permissions

There is **no permission-change stream** in this version. The only status
stream is for the location *service* (GPS on/off), and it is unsupported on
web:

```dart
// geolocator_platform_interface-4.4.0 (abstract)
Stream<ServiceStatus> getServiceStatusStream();

// geolocator_web-4.1.4/lib/geolocator_web.dart
@override
Stream<ServiceStatus> getServiceStatusStream() =>
    throw _unsupported('getServiceStatusStream');
```

`_unsupported` returns an `UnsupportedError`, and because the getter body is
`=> throw ...`, the throw happens synchronously when the stream is requested
on web.

Implications for UI_SPEC 7.7:
- The "re-check automatically on `AppLifecycleState.resumed`" plan is the
  correct approach on both platforms: call `Geolocator.checkPermission()` again
  on resume, and re-arm `requestPermission()` only if the state moved back to
  `denied`.
- Do not subscribe to `getServiceStatusStream()` unconditionally on web; guard
  it with `!kIsWeb`.
- `LocationSettings` configures the stream only; it has no listener:

```dart
class LocationSettings {
  const LocationSettings({
    this.accuracy = LocationAccuracy.best,
    this.distanceFilter = 0,
    this.timeLimit,
  });
  final LocationAccuracy accuracy;
  final int distanceFilter;
  final Duration? timeLimit;
}
```

`AndroidSettings extends LocationSettings` adds `forceLocationManager`,
`intervalDuration`, `foregroundNotificationConfig` (the
`ForegroundNotificationConfig` type that drives the Android foreground service
notification) and `useMSLAltitude`. `WebSettings` and `AppleSettings` are
re-exported by the `geolocator` package (geolocator.dart lines 14-17).

### 4.4 Important: openAppSettings / openLocationSettings on web

`geolocator_web-4.1.4/lib/geolocator_web.dart` (lines 128-133):

```dart
@override
Future<bool> openAppSettings() => throw _unsupported('openAppSettings');

@override
Future<bool> openLocationSettings() =>
    throw _unsupported('openLocationSettings');
```

On web it is therefore impossible to open OS settings from the app, exactly as
the UI_SPEC web branch states. The browser address-bar instructions plus a
"Já permiti, tentar de novo" button that calls `checkPermission()` are the only
option. Guard both calls with `!kIsWeb` and a try/catch, because they throw
synchronously. On Android they return a `bool` (`true` if the page opened),
sourced from the method channel `openAppSettings` / `openLocationSettings`
calls in `geolocator_android-5.1.1+1/lib/src/geolocator_android.dart`.

### 4.5 Cross-check against the repo

`permission_handler` is **already present** in `app/pubspec.yaml`
(`permission_handler: ^12.0.0`), so UI_SPEC 2.2's "`permission_handler` unless
already present" allows it, and PLAN.md line 1039 records it as approved by
ADR 2026-10-10 for the Android 13+ notification permission. Its role here is
notifications only; location stays with `geolocator`.

## 5. `--analyze-size` for apk and web

### 5.1 `flutter build apk --analyze-size`: EXISTS

Verified by reading the flag help from the installed tool:

```
$ flutter build apk --help
--[no-]analyze-size     Whether to produce additional profile information for
                        artifact output size. This flag is only supported on
                        "--release" builds. When building for Android, a single
                        ABI must be specified at a time with the
                        "--target-platform" flag. ...
                        This flag cannot be combined with "--split-debug-info".
--code-size-directory   The location to write code size analysis files. If this
                        is not specified, files are written to a temporary
                        directory under the build directory.
```

Sources:
- `/home/edubot/flutter/packages/flutter_tools/lib/src/runner/flutter_command.dart`
  line 136: `static const kAnalyzeSize = 'analyze-size';`.
- `usesAnalyzeSizeFlag()` is called from `BuildApkCommand`
  (`lib/src/commands/build_apk.dart`) and from `build_appbundle`,
  `build_ios`, `build_macos`, `build_linux`, `build_windows`.
- https://docs.flutter.dev/perf/app-size lists exactly these six commands and
  does not list `flutter build web`.

Exact syntax:

```bash
flutter build apk --analyze-size --target-platform android-arm64 --release
```

`--release` is implied by `flutter build apk` but the flag only takes effect on
release builds (the tool exits with
`"--analyze-size" can only be used on release builds.` otherwise).

### 5.2 `flutter build web --analyze-size`: DOES NOT EXIST

Verified by running it against the project:

```
$ flutter build web --analyze-size
Could not find an option named "--analyze-size".
```

Sources:
- `BuildWebCommand` (`/home/edubot/flutter/packages/flutter_tools/lib/src/commands/build_web.dart`)
  never calls `usesAnalyzeSizeFlag()` and never calls
  `import '../base/analyze_size.dart'`, unlike the Android/iOS/desktop
  commands.
- `flutter build web --help` has no `analyze-size` and no `code-size-directory`.
- The official size doc above lists web nowhere.

So UI_SPEC 11.4's "`flutter build apk --analyze-size` / `flutter build web
--analyze-size` (or the pinned version's equivalent)" must be corrected: for
web there is no `--analyze-size` equivalent. Use one of:

```bash
# Get the raw numbers for the web bundle and the deferred chunks.
flutter build web --release
du -b build/web/*.js build/web/*.part.js

# Optional per-symbol breakdown, if a deeper look is needed.
flutter build web --dump-info
```

**VERIFY item for the owner:** the U21 size measurements in UI_SPEC section 17
should use `du` on `build/web` (plus `flutter build apk --analyze-size` for
Android), and UI_SPEC 11.4 should be updated to say that
`flutter build web --analyze-size` does not exist in 3.47.6.

### 5.3 Web renderer flag changed (also affects UI_SPEC 8 and 11.3)

`--web-renderer` no longer exists. `flutter build web --help` shows no such
option, and `grep -rn "web-renderer"` in `flutter_tools/lib/src` returns
nothing. The renderer is now selected by dart defines or the `--wasm` flag.
Source: `/home/edubot/flutter/packages/flutter_tools/lib/src/web/compile.dart`
lines 186-220:

```dart
enum WebRendererMode {
  canvaskit,
  skwasm;

  factory WebRendererMode.fromDartDefines(Iterable<String> defines, {required bool useWasm}) {
    if (defines.contains('FLUTTER_WEB_USE_SKIA=false') &&
        defines.contains('FLUTTER_WEB_USE_SKWASM=true')) {
      return skwasm;
    } else if (defines.contains('FLUTTER_WEB_USE_SKIA=true') &&
        defines.contains('FLUTTER_WEB_USE_SKWASM=false')) {
      return canvaskit;
    }
    return getDefault(useWasm: useWasm);
  }

  static WebRendererMode getDefault({required bool useWasm}) =>
      useWasm ? defaultForWasm : defaultForJs;

  static const WebRendererMode defaultForJs = WebRendererMode.canvaskit;
  static const WebRendererMode defaultForWasm = WebRendererMode.skwasm;
}
```

So: default for a JS build is **CanvasKit** (matches the UI_SPEC assumption);
default for a `--wasm` build is **Skwasm**. Combining `--wasm` with an explicit
renderer dart define is a tool exit
("Do not attempt to set a web renderer when using --wasm").

## 6. OpenStreetMap tile usage policy (tile.openstreetmap.org)

Source: https://operations.osmfoundation.org/policies/tiles/ (Tile Usage
Policy, retrieved 2026-10-10).

### 6.1 Requirements (quoted)

"You must:
- Use the correct URL: `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.
- Provide visible **licence attribution**, following the Attribution
  Guidelines.
- Send a **valid HTTP User-Agent** that clearly identifies your application
  (or a platform `X-Requested-With` app ID where set automatically).
- From web pages, ensure a valid **HTTP Referer** header is sent.
- **Cache** tiles locally according to HTTP caching headers (or at least **7
  days** if your cache cannot read them).
- Avoid encouraging or enabling copyright infringement."

"You must not:
- Bulk download ("scrape") tiles or offer prefetch features.
- Send `Cache-Control: no-cache`, `Pragma: no-cache`, or similar no-cache
  headers by default.
- Set a restrictive Referrer-Policy that prevents the **HTTP Referer** header
  being sent.
- Use the **HTTP** URL ... use the **HTTPS** URL from above.
- Masquerade as another app's User-Agent, or rely on a library's default
  User-Agent."

On identification specifically:

"**User-Agent:** Send a clear, unique User-Agent string that names your app and
optionally includes a contact URL or email. Example (good):
`User-Agent: MyTownMaps/1.4 (+https://example.org; contact: maps@example.org)`
Browsers will use the browser's default `User-Agent`."

"Do **not** use a library default `User-Agent`, and never impersonate another
app or a browser."

"Traffic that uses these defaults **will be blocked** because we cannot
identify or contact the actual application."

On caching:

"**Do not bypass caches.** Never send `Cache-Control: no-cache`,
`Pragma: no-cache`, or similar no-cache headers by default. **Honour server
caching headers** (`Cache-Control`, `Expires`, `Etag`). If your cache cannot
read them, cache each tile for **at least 7 days**."

On bulk download:

"**Bulk downloading** is any pre-emptive fetching of tiles other than those a
user is actively viewing. This includes, but is not limited to: 'Pre-seeding'
large areas or multiple zoom levels in advance. Building tile archives (e.g.
`.zip`, `.mbtiles`) for later distribution. Automated scans across wide
bounding boxes, especially at high zoom (z>=14). Headless bots that pan/zoom
the map to force rendering. **Offline use is not permitted on
`tile.openstreetmap.org`.**"

"Permitted usage (examples): Normal interactive viewing by a human where the
client requests only the tiles needed for the current viewport (with modest,
short-range look-ahead typical of browsers)."

### 6.2 What this means for this repo

- **User-Agent on native.** `TileLayer.userAgentPackageName` is the hook
  (flutter_map 8.3.2, see 1.5). flutter_map injects
  `'flutter_map ($userAgentPackageName)'` only when `!kIsWeb`. Because the
  policy forbids relying on a library default, the app must override the header
  with an app-specific string via the tile provider:

```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'br.com.pontual.app',
  tileProvider: NetworkTileProvider(
    headers: const <String, String>{
      // policy: clear, unique UA naming the app, stable across releases
      'User-Agent': 'Pontual/1.0 (+https://edubot.github.io/pontual-bus-tracking)',
    },
  ),
)
```

- **User-Agent on web is not settable.** flutter_map's own docs state that "On
  the web, the 'User-Agent' header cannot be changed, as specified in
  [TileLayer.tileProvider]'s documentation, due to a Dart/browser limitation",
  and the OSM policy explicitly accepts this ("Browsers will use the browser's
  default `User-Agent`"). For web the requirements to satisfy are the **Referer**
  header and the HTTP **Referrer-Policy**: do not set a restrictive
  `referrer` meta tag or header. Flutter's generated `web/index.html` does not
  set one by default, so verify nothing adds one before release.
- **Caching.** The default `NetworkTileProvider()` uses a session-only in-memory
  cache plus flutter_map's `BuiltInMapCachingProvider` on native (PLAN.md D12
  relies on the ">= 8.2.0 built-in cache", which matches this version). The
  built-in provider honours HTTP headers, and its doc says
  "Usually uses HTTP headers to determine tile freshness". The policy's 7-day
  floor is satisfied by that path. Note the cache is **not** an offline feature:
  it is a repeat-view cache only. The project hard limit "never bulk-download
  or prefetch OSM tiles" already matches the policy's section 4.
- **Attribution is mandatory and must be visible.** The UI_SPEC attribution chip
  (top-right, tappable to the OSM copyright page) satisfies this. Keep it on
  screen at all times, including when the sheet is at `full` and in both themes.
- **Data saver.** With `dataSaver` on, the map stays collapsed until requested
  (UI_SPEC 7.8), which also keeps tile requests low. This is the correct
  behaviour under the policy and needs no extra work.
- **Attribution/exit plan.** The policy warns access "may be blocked without
  prior notice" and recommends an alternative for heavy use. PLAN.md R-05 and
  D12 already record the `TileSource` exit plan; the token palette/ADR work in
  U04 is unaffected.

### 6.3 Unverified items

- The actual tile cache size cap (PLAN.md S3 mentions "~50 MB"): the
  `BuiltInMapCachingProvider` default in the installed 8.3.2 is
  `maxCacheSize = 1_000_000_000` (1 GB), and the project must set a smaller cap
  explicitly. **The 50 MB figure is not yet wired; needs an ADR or a config
  value.**
- Whether the OSM servers send `Cache-Control` that maps to >= 7 days was not
  tested (no network probes were made against the production tile server, per
  the project rule about not running load tests). The code path honours server
  headers, which is what the policy requires.

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


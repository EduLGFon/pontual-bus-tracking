# AUDIT.md - U01 repository audit (before the new UI)

Scope: `docs/ui/UI_SPEC.md` rule 1 ("Task U01 is a repository audit") and
rule 5 "Measure before and after". This document maps the concepts named by
UI_SPEC sections 5, 6 and 7 to what actually exists in `app/lib/` today,
lists what the new UI may not touch, the pieces it reuses, the baseline
metrics and the gaps. Every claim cites a file path and a real symbol.

Audit date: 2026-10-10, updated the same day after the parallel
implementation landed the design-system layer. Package versions come from
`app/pubspec.yaml`, `app/pubspec.lock` and `.fvmrc`; no command was re-run
to confirm them.

Two caveats up front:

- `docs/ui/UI_SPEC.md` stops at section 13.5 (line 868). Its table of
  contents lists sections 14 to 18, including section 16 (the task list) and
  section 17 (the measurement protocol) that this audit is told to satisfy.
  Neither is in the file, so this audit maps sections 5, 6 and 7 only and
  treats the task numbering as unknown (gap 19).
- The tree moved while the audit was being written: a bundled font, three
  additive fields on `StaticLine`, a web user-agent helper, 29 component
  files, 4 icon painters, 6 adapters and a `TripVM` model all landed in
  `app/lib/ui/**` and `app/lib/platform/web/`. Everything below reflects the
  tree as of the last edit of this file. `app/lib/ui/**` holds 58 Dart files
  in total and is imported by nothing outside itself.

## 0. How to read this document

- **exists** = the file and the public symbol are in the repo today.
- **partial** = something exists under that name but with fewer
  responsibilities, a different shape, or not wired to the running app.
- **missing** = nothing in the repo implements it.
- The new UI layer `app/lib/ui/**` is complete at the design-system and
  adapter level but is still not consumed: `grep -rn "package:pontual/ui/"`
  over `app/lib` and `app/test` returns no match outside `app/lib/ui/`, and
  `app/lib/main.dart` still builds `MaterialApp.router` with
  `buildRouter()` from `app/lib/app/router.dart` and `lightTheme()` /
  `darkTheme()` from `app/lib/app/theme.dart`. There is no
  `app/lib/ui/shell/`, no `app/lib/ui/features/` and no `/_gallery` route.

---

## 1. Existing UI map

### 1.1 Concepts from UI_SPEC section 5 (component catalog)

| UI_SPEC concept | Status | What exists today | Notes |
|---|---|---|---|
| `Certainty` enum | exists | `app/lib/ui/models/certainty.dart` `enum Certainty {live, predicted, scheduled, stale}`; `liveFreshS` = 45, `certaintyForAge(int)`, `certaintyRank(Certainty)`, `isMeasured(Certainty)`, `certaintyLabelKeys`, `CertaintyDebug.debugName` | Same four values as the spec. |
| `CertaintyStyle` | exists | `app/lib/ui/design/components/certainty_style.dart` `@immutable class CertaintyStyle {certainty, label, icon, dashed, prefix, graphic, text}` and `CertaintyStyle styleOf(BuildContext, Certainty)`; labels from `UiStrings.certaintyLive` and siblings | The single style table the spec asks for; `dashed` and `prefix` are true and `'~'` for `predicted` only. |
| `CertaintyBadge` | exists | `app/lib/ui/design/components/certainty_badge.dart` `CertaintyBadge({required Certainty certainty, bool compact = false, VoidCallback? onInfo})` | Renders through `styleOf`, so no screen invents its own. |
| `LiveDot` | exists | `app/lib/ui/design/components/live_dot.dart` `LiveDot({required certainty, ...})` plus `LiveDotPainter` | Pulse is driven by `LivePulse` below. |
| `LivePulse` | exists | `app/lib/ui/design/components/live_pulse.dart` `LivePulse` | One shared controller, as the spec requires. |
| `BusIcon`, `LiveWavesIcon`, `RouteIcon`, `SparkIcon` | exists (painters) | `app/lib/ui/design/icons/` `BusIconPainter`, `LiveWavesIconPainter`, `RouteIconPainter`, `SparkIconPainter` | `CustomPainter` implementations; only 4 of the 6 named icons exist (no `ClockIcon`, no `TerminalIcon`). |
| `LineBadge` | exists | `app/lib/ui/design/components/line_badge.dart` `LineBadge({required String lineKey, required String text, BadgeSize size = BadgeSize.m, Color? color, String? heroTag})`, `factory LineBadge.ofLine(LineVM, {BadgeSize size, String? heroTag})`, `enum BadgeSize` | Colour comes from `lineColorOf`, text colour from `lineBadgeTextOf`. |
| `EtaText` | exists | `app/lib/ui/design/components/eta_text.dart` `EtaText({required String primary, String? secondary, bool hero = false, String? semanticLabel})`, `factory EtaText.ofArrival(ArrivalVM, DateTime, {bool hero, String? semanticLabel})` | Uses `formatEta` and `PontualText.etaHero` / `etaLarge` with tabular figures. |
| `formatEta` | exists | `app/lib/ui/util/format_eta.dart` `EtaFormat {primary, secondary, a11y}`, `formatEta(ArrivalVM, DateTime)`, `minutesUntilClock`, `formatHours`, `formatClock`, `isStaleArrival`, `hourLabelOf`, `minuteOf` | Pure Dart, no Intl. Reads `DateTime.hour`/`minute`, matching the UTC-offset `DateTime`s that `saoMateusTime` returns. |
| `ArrivalRow` | exists | `app/lib/ui/design/components/arrival_row.dart` `ArrivalRow({required ArrivalVM arrival, required DateTime now, required LineVM line, VoidCallback? onTap, Widget? trailing, bool large = false, String? headline})` | |
| `LineRow` | exists | `app/lib/ui/design/components/line_row.dart` `LineRow({...})` | |
| `VehicleRow` | exists | `app/lib/ui/design/components/vehicle_row.dart` `VehicleRow({...})` | |
| `VehicleMarker` | exists | `app/lib/ui/design/components/vehicle_marker.dart` `VehicleMarker({required VehicleVM vehicle, required String lineKey, bool selected = false, VoidCallback? onTap, Animation<double>? pulse, Color? ringColor, Color? glyphColor})` plus `VehicleMarkerPainter` | Takes the shared `pulse` animation instead of owning a controller. |
| `ShortcutCard` | exists | `app/lib/ui/design/components/shortcut_card.dart` `ShortcutCard({required String label, required LineVM line, ArrivalVM? arrival, DateTime? now, IconData icon, VoidCallback? onTap, VoidCallback? onLongPress})` and `AddShortcutCard` | |
| `SectionHeader` | exists | `app/lib/ui/design/components/section_header.dart` `SectionHeader({...})` | |
| `SearchField` | exists | `app/lib/ui/design/components/search_field.dart` `SearchField({required String hint, TextEditingController? controller, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, bool autofocus = false, FocusNode? focusNode, String? semanticLabel})` and `SearchEntry({required String hint, VoidCallback? onTap})` | |
| `Sheet` | exists | `app/lib/ui/design/components/pontual_sheet.dart` `PontualSheet({required Widget child, String? title, VoidCallback? onInfo, bool scrollable = false, EdgeInsetsGeometry padding})` | Single sheet container with the drag handle and the one allowed shadow. |
| `TimeRail` | exists | `app/lib/ui/design/components/time_rail.dart` `TimeRailHour({required String hour, required List<String> minutes})`, `TimeRail({required List<TimeRailHour> hours, String? nextHour, String? nextMinute, int? nowMinutes, ValueChanged<String>? onSelect, ScrollController? scrollController})` | |
| `Banner` | exists | `app/lib/ui/design/components/banner.dart` `Banner({required String message, BannerTone tone = BannerTone.info, IconData? icon, String? actionLabel, VoidCallback? onAction, String? semanticLabel})`, `enum BannerTone`, `BannerSlot({required banner})` | |
| `Toast` | exists | `app/lib/ui/design/components/toast.dart` `ToastController({Duration duration = const Duration(seconds: 3)})`, `ToastData({required message, actionLabel, onAction})`, `ToastSlot({required controller})` | Queue is a single controller, so "queue max 1" is enforced by construction. |
| `EmptyState` | exists | `app/lib/ui/design/components/empty_state.dart` `EmptyState({required String title, required String message, EmptyArt art = EmptyArt.bus, String? actionLabel, VoidCallback? onAction, String? secondaryLabel, VoidCallback? onSecondary})`, `enum EmptyArt`, `EmptyArtPainter` | Vector art, no image files. |
| `Skeleton` | exists | `app/lib/ui/design/components/skeleton.dart` `Skeleton`, `SkeletonHost`, `SkeletonScope`, `PulsingSkeleton`, `Delayed({required Duration delay, required Widget child})`, `SkeletonList({int count = 4})` | One shared pulse, and `Delayed` implements the 300 ms rule. |
| `TripDock` | exists | `app/lib/ui/design/components/trip_dock.dart` `TripDock({required TripVM trip, required String idleLabel, VoidCallback? onTap, double maxWidth = 420})` | Renders `TripPhase.idle/starting/active/reconnecting/paused` from `app/lib/ui/models/trip_vm.dart`. |
| `PermissionCard` | exists | `app/lib/ui/design/components/permission_card.dart` `PermissionCard({...})`, `enum PermissionCardState` | |
| `Pressable` | exists | `app/lib/ui/design/components/pressable.dart` `Pressable({...})` | Tint plus scale, no ink splash. |
| Buttons | exists | `app/lib/ui/design/components/buttons.dart` `PrimaryButton`, `SecondaryButton`, `GhostButton`, `DangerButton` | |
| `IconBtn`, `GhostLink` | exists | `app/lib/ui/design/components/icon_btn.dart` `IconBtn`, `app/lib/ui/design/components/ghost_link.dart` `GhostLink` | |
| `Chip` | exists | `app/lib/ui/design/components/chip.dart` `Chip({...})` | |
| `Segmented` | exists | `app/lib/ui/design/components/segmented.dart` `Segment({required String value, required String label})`, `Segmented({required List<Segment> segments, required String value, required ValueChanged<String> onChanged, Haptics haptics = const Haptics()})` | Custom control with `AnimatedAlign` and selection haptics, not `SegmentedButton`. |
| `Sparkline`, `ConfidenceMeter` | missing | nothing | Correctly absent: `Features.predictions` and `Features.reliability` are `false`. |
| Gallery route `/_gallery` | missing | nothing | No route in `app/lib/app/router.dart` and no `app/lib/ui/design/gallery/`. |
| `DashedOutline` (support) | exists | `app/lib/ui/design/components/dashed_outline.dart` `DashedOutline`, `SurfaceCard` in `surface_card.dart` | Shared helpers the spec implies but does not name. |

### 1.2 Concepts from UI_SPEC section 6 (UI architecture)

| UI_SPEC concept | Status | What exists today | Notes |
|---|---|---|---|
| `LineVM` | exists | `app/lib/ui/models/line_vm.dart` `LineVM({required String key, required String name, String? short, List<String> terminals = const [], List<String> areaTags = const [], bool isLive = false, int liveVehicleCount = 0, bool supportsSharing = false, Color? color})`, `badgeText`, `terminalsText`, `withLive({required bool isLive, required int liveVehicleCount})` | Built by `lineVmOf`, not yet consumed by a screen. |
| `ArrivalVM` | exists | `app/lib/ui/models/arrival_vm.dart` `ArrivalVM({required String lineKey, required DateTime at, required Certainty certainty, required DateTime asOf, String? stopKey, String? headsign, String? originLabel, int? confidence, int? delaySeconds})`, `isPast(DateTime)`, `secondsUntil(DateTime)` | |
| `VehicleVM` | exists | `app/lib/ui/models/vehicle_vm.dart` `VehicleVM({required int key, required String lineKey, required double lat, required double lng, double? headingDeg, double? speedKmh, required int ageSeconds, required Certainty certainty, int? ordinal})`, `showsHeading`, `withOrdinal(int)` | |
| `ShortcutVM` | exists | `app/lib/ui/models/shortcut_vm.dart` `ShortcutKind {home, work, school, university, custom}`, `ShortcutVM({kind, label, lineKey, originLabel})`, `toJson()`, `ShortcutVM.fromJson(Map)` | |
| `TripVM` / `TripPhase` | exists | `app/lib/ui/models/trip_vm.dart` `enum TripPhase {idle, starting, active, reconnecting, paused}`, `TripVM({phase, lineKey, lineLabel = '', elapsedS = 0, gpsOff = false, webHidden = false, role = 'waiting'})`, `inProgress`, `dockMessage` | Built by `tripVmOf(TripController)`. `dockMessage` returns pt-BR literals, which duplicates `UiStrings` (gap 15). |
| `AlertRuleVM`, `ReliabilityVM` | missing | nothing | Correctly absent: flags are `false`. |
| `ArrivalsSource` seam | exists | `app/lib/ui/adapters/arrivals_adapter.dart` `abstract interface class ArrivalsSource { Stream<List<ArrivalVM>> watch(ArrivalQuery query); }`, `class ArrivalQuery`, `class TimetableArrivalsSource implements ArrivalsSource` (`watch`, `departures(ArrivalQuery)`, `originsFor(String dayType)`, `timesFor(String dayType, String? origin)`) | `LiveAwareArrivalsSource` and `CompositeArrivalsSource` do not exist yet, but the interface the spec names is in place. |
| `SearchProvider` seam | partial | `app/lib/ui/util/search_index.dart` `normalizeText`, `LineIndex`, `buildLineIndex`, `searchLines`, `LineMatch`, `MatchRank`, `matchesAllTokens`, `highlightRanges` | Still a function set, not an interface with kinds; no stop or place kind. |
| `FavoritesStore` | exists | `app/lib/ui/adapters/local_stores.dart` `FavoritesStore` with `read()`, `toggle(String key)`, `write(Set<String>)`, key `favoritesKey = 'ui_favorites_v1'` | |
| `RecentsStore` | exists | same file, `RecentsStore` with `read()`, `add(String key)`, `clear()`, key `recentsKey = 'ui_recents_v1'` | |
| `ShortcutsStore` | exists | same file, `ShortcutsStore` with `read()`, `write(List<ShortcutVM>)`, key `shortcutsKey = 'ui_shortcuts_v1'` | |
| `AlertsStore` | missing | nothing | Flagged off. |
| `Features` flags | exists, unwired | `app/lib/ui/models/features.dart` `Features({shortcuts = true, recents = true, favorites = true, dataSaver = true, predictions = false, eta = false, arrivalAlerts = false, reliability = false, followVehicle = true, routeLine = false})`, `copyWith`, `static Features fromJson(Map<String, dynamic>)` (snake_case, unknown or non-bool ignored) | No Riverpod provider exposes `Features`, and no `localKudos` flag (gap 14). `RemoteConfig` still has no flags object (gap 4). |
| `Breakpoint` | exists | `app/lib/ui/design/tokens/spacing.dart` `enum Breakpoint {compact, medium, expanded}`, `static Breakpoint of(double)`, `marginFor(BuildContext)` | Thresholds 600 and 840 as specified. |
| `AdaptiveScaffold` | missing | nothing | No `app/lib/ui/shell/` at all. |
| Theme extension tokens | exists, unused by the app | `app/lib/ui/design/tokens/colors.dart` `PontualColors extends ThemeExtension<PontualColors>` (all 22 fields, `light`, `dark`, `copyWith`, `lerp`, `graphicOf`, `textOf`); `app/lib/ui/design/theme/theme.dart` `pontualLightTheme()`, `pontualDarkTheme()`; `app/lib/ui/design/theme/context.dart` `extension PontualContext on BuildContext` (`colors`, `text`), `PontualTextStyles` | `app/lib/main.dart` still calls `app/lib/app/theme.dart`. |
| Text tokens and font | exists | `app/lib/ui/design/tokens/text.dart` `PontualText.etaHero/etaLarge/display/title/headline/body/bodyStrong/label/caption/clock`, `pontualFontFamily = 'Manrope'`, `weightAxis = 'wght'`; `app/assets/fonts/Manrope.ttf` (51712 bytes); `app/pubspec.yaml` `fonts:` block declaring family `Manrope`; `tools/build_fonts/subset_manrope.py` regenerates it with fonttools and fails above 70 KB | The font is now really bundled, so `FontVariation` and tabular figures work. |
| `LineColors` | exists | `app/lib/ui/design/tokens/line_colors.dart` `linePaletteLight`, `linePaletteDark`, `paletteOf(Brightness)`, `stableHash(String)`, `lineColorOf(String, {required Brightness brightness, String? override})`, `lineBadgeTextOf(Color)`, `parseHexColor(String)` | Free functions rather than a `LineColors` class; the spec allows the rename. |
| Contrast maths | exists | `app/lib/ui/util/contrast.dart` `relativeLuminance`, `contrastRatio`, `bestTextOn`, `ensureContrast`, `nearBlackOnFill`, `whiteOnFill` | No `contrast_test.dart` yet (gap 16). |
| Spacing, radii, sizes | exists | `app/lib/ui/design/tokens/spacing.dart` `Space.x1..x12`, `Radii.s/m/l/sheet/pill`, `hitTarget = 48`, `Sizes.navBar/dock/button/buttonCompact/chip/search/shortcutWidth/shortcutHeight/marker/markerHit/badgeS/badgeM/badgeL` | |
| Motion | exists | `app/lib/ui/design/tokens/motion.dart` `Motion.instant/fast/base/slow/pulse/markerMove`, `MotionCurves.enter/exit/move`, `motionDuration(Duration, {required bool enabled})` | |
| `Haptics` | exists | `app/lib/ui/util/platform.dart` `Haptics({bool enabled = true})` with `selection()`, `light()`, `medium()`; `PlatformInfo.isWeb/isAndroid/isIos`; `BrowserFamily`, `browserFamilyOf(String)` | |
| `NowTicker` | exists | `app/lib/ui/adapters/now_clock.dart` `currentNowProvider`, `nowTickProvider` (minute-aligned), `nowSecondTickProvider` (per second) | Both are `StreamProvider<int>`; the per-second one is for the trip screen only. `arrivals_adapter.dart` adds `nowProvider` for the São Mateus wall clock. |
| Deferred map import | missing | nothing | `app/lib/features/line/map_tab.dart` imports `flutter_map` eagerly; no `deferred as` anywhere in `app/lib`. |

### 1.3 Concepts from UI_SPEC section 7 (screens)

| UI_SPEC screen | Status | What exists today | Notes |
|---|---|---|---|
| App shell, bottom nav, dock host, banner and toast slots | missing | nothing | `app/lib/app/router.dart` is flat, no shell widget. `BannerSlot` and `ToastSlot` exist as components but nothing hosts them. |
| `/` Início | partial | `app/lib/features/home/home_screen.dart` `HomeScreen` | No greeting, no shortcuts, no recents, no live summary chip, no `EmptyState`, no pull-to-refresh, no welcome card. It is the legacy screen and stays until cutover. |
| `/search` | missing | no route, no screen | `searchLines` and `SearchField` are ready. |
| `/lines` | partial | no route; `linesVmProvider` and `LineRow` exist | No filter chips, no favourites, no virtualised list. |
| `/line/:key` | partial | `app/lib/app/router.dart` `GoRoute(path: '/line/:id')` with `int.tryParse`; `app/lib/features/line/line_screen.dart` `LineScreen({required int lineId})`; `lineByKeyProvider` exists for key lookups | The app route still takes an integer id, so `LineVM.key` has no deep link yet. |
| Line sheet (peek/half/full) | missing | `PontualSheet` exists as a component | No screen uses it, no `DraggableScrollableSheet`, no snap points. |
| Map layer | partial | `app/lib/features/map/tile_source.dart` `osmTileLayer`, `mapBounds`, `mapMinZoom`, `mapMaxZoom`, `tileUserAgent`, `tileCacheMaxBytes`; `app/lib/features/map/map_widget.dart` `PontualMap` (only used by `app/test/map_test.dart`); `app/lib/features/line/map_tab.dart` `PontualMapWithMarkers` | No `mapScrim`, no attribution chip pill, no follow mode, no zoom controls, no marker cap, no deferred import. |
| Route polyline | partial | `PontualMapWithMarkers({..., route = const <LatLng>[]})`; `core/geo.decodePolyline` | `route` is never passed and `decodePolyline` returns `core/geo.LatLng`, not `latlong2.LatLng`. |
| Timetable tab | partial | `app/lib/features/line/schedule_tab.dart` `ScheduleTab({required line, required now})`; `TimeRail` and `TimetableArrivalsSource` exist | The legacy tab stays; the new one is not built. |
| `/trip` | partial | `app/lib/features/trip/trip_screen.dart` `TripScreen`, `TripRoute`, `EndCard`; `TripDock` and `TripVM` exist | `TripScreen` still uses its own 1 s `Timer`; `TripVM` is not consumed. |
| `/settings`, `/privacy`, `/about` | partial | legacy `SettingsScreen`, `PrivacyScreen`, `AboutScreen`; `SettingsStore` / `SettingsNotifier` / `settingsProvider` exist for data saver and reduce motion | No new settings screen. |
| `/system/:kind` | partial | `app/lib/features/system/system_screen.dart` `SystemKind`, `SystemScreen`, `OfflineBanner`; route is `/system` with no parameter | No update action, no not-found route. |
| First run | partial | `app/lib/app/router.dart` `initialLocation: '/welcome'`, `WelcomePlaceholder`; `UiStrings.welcomeTitle/welcomeBody/welcomePrivacy/coachmark` | Still a route, not a dismissible card; no coachmark widget. |
| Trip flow entry | missing | `app/lib/features/trip/share_flow.dart` `shareTrip(...)` | No dock, no line chooser sheet. |

### 1.4 Cross-cutting pieces

| Concept | Status | What exists today |
|---|---|---|
| Strings files | partial | `app/lib/app/strings_pt.dart` `class StringsPt` (legacy, wired to the live app) and `app/lib/ui/strings/ui_strings.dart` `class UiStrings` (651 lines, 10 sections, consumed by the new components). Not merged. |
| Router | partial | `app/lib/app/router.dart` `GoRouter buildRouter()`, `initialLocation: '/welcome'`, routes `/welcome`, `/`, `/line/:id`, `/trip`, `/settings`, `/privacy` (children `policy`, `terms`), `/about`, `/system`; helpers `placeholder`, `WelcomePlaceholder`, `TripPlaceholder`, `SystemPlaceholder` |
| Theme in use | partial | `app/lib/main.dart` uses `lightTheme()` / `darkTheme()` from `app/lib/app/theme.dart`; the new `pontualLightTheme()` / `pontualDarkTheme()` are unused |
| Browser detection | exists | `app/lib/platform/web/user_agent.dart` `String userAgent()` with conditional imports `user_agent_stub.dart` / `user_agent_web.dart` (`dart:js_interop`, returns `''` off web) |

---

## 2. What the new UI may not touch

UI_SPEC 0.1 rule 2 freezes the API client, authentication, consent
recording, tracking and ping logic, static-data loading and backend
contracts. The new UI reads them through providers and adapters only.

### 2.1 Frozen files

| File | Public API the UI calls | Frozen because |
|---|---|---|
| `app/lib/data/api/bus_api.dart` | `BusApi({client, baseUrl, readToken, writeToken})`, `ensureRegistered()`, `postConsents(String, int)`, `startTrip(String, {lineId, lat, lng, accuracyM, batteryPct, charging, resume})`, `pingTrip(String, {seq, lat, lng, speedMps, heading, accuracyM, batteryPct, charging, role})`, `endTrip(String)`, `deleteMe(String)`, `getVehicles(int)`, `getLive()`, `BaseUrlProvider` | API contract, token handling, PLAN.md 6.5 |
| `app/lib/data/api/dto.dart` | `TripInstruction {role, intervalS, end}`, `VehiclesSnapshot {epochS, vehicles}`, `LiveLines(rows)`, `mapError(int, String?)` | Wire format |
| `app/lib/data/prefs/token_store.dart` | `TokenStore.read()`, `write(String)`, `clear()`, `tokenPrefsKey` | Auth, LGPD |
| `app/lib/data/prefs/consent_store.dart` | `ConsentStore` (`read`, `write`, `covers`, `readPosted`, `markPosted`, `clearPosted`, `clear`), `consentVersionKey`, `consentPostedKey` | Consent recording, LGPD |
| `app/lib/data/static_data/static_data.dart` | `StaticDataRepository({client, staticBaseUrl, bundleManifestJson, bundleLinesJson, prefs, nowMs})`, `lines()`, `refresh()`; `StaticLine` (now also `terminals`, `areaTags`, `isActive`, all defaulted); `linesKeyPrefix`, `manifestKey`, `checkInterval`, `headerOf` | Static data loading, offline-first. The three new fields are additive with defaults, so old bundles still parse; that keeps the load path frozen. |
| `app/lib/data/realtime/vehicle_repository.dart` | `VehicleRepository({fetchSnapshot, openChannel, wsBaseUrl, clock, launch, reconnectDelays})`, `start(int)`, `stop()`, `vehicles`, `status`, `evaluateAge()`, `lastSnapshotAtMs`; `ClientVehicle`; `StreamStatus`; `staleAfterS`, `watchdogResyncS`, `pollFallbackAfterS`, `pollIntervalS`, `reconnectDelaysS`, `ChannelFactory`, `SnapshotFetcher` | Stream lifecycle |
| `app/lib/features/trip/trip_controller.dart` | `TripController(TripDeps)`, `TripDeps`, `StartFailure`, `TripEndKind`, `state`, `lineId`, `lineLabel`, `endKind`, `endDetail`, `startedAtMs`, `failReason`, `lastErrorCode`, `isWebHidden`, `walkingPromptVisible`, `isOffline`, `isPaused`, `startTrip({lineId, lineLabel, showConsent, showPermissions, firstFixTimeout, onPhase})`, `cancelStart()`, `confirmStillRiding()`, `confirmLeftBus()`, `endTrip()`, `setWebHidden(bool)`, `checkAutoEndForTest()`, `onFixForTest(TripFix)` | The only place that starts or stops the foreground service and sends pings (AGENTS.md 7) |
| `app/lib/features/trip/location_service.dart` | `LocationService.production()`, `fixes({mode, lineLabel})`, `requestMode(SamplingMode, int)`, `stop()`, `settingsFor(SamplingMode, String)`, `TripFix`, `RawFix`, `acceptFix`, `dropReason`, `normalizeSpeed`, `normalizeHeading`, `round5`, `batteryBucket`, `fixArea`, `fixMaxAgeMs` | Privacy, foreground service |
| `app/lib/features/trip/ping_client.dart` | `PingClient({send, refreshToken, random, delay})`, `queue(Map, void Function(PingOutcome))`, `consecutiveFailures`, `PingReply`, `PingOutcome` | Ping scheduling, battery |
| `app/lib/features/trip/trip_supervisor.dart` | `TripSupervisor({gateway})`, `Supervision`, `pollEnvironment(int)`, `onFix(TripFix, int)`, `onPingSuccess(int)`, `evaluate({role, failures, wasOffline, startedAtMs, nowMs})`, `confirmStillRiding()`, `reset()`, `offlineAfterFailures`, `permissionRevokedAfterPolls`, `offlineAfterMs` | Auto-end policy, battery |
| `app/lib/features/trip/share_flow.dart` | `Future<void> shareTrip(BuildContext, WidgetRef, StaticLine, {PermissionGateway gateway, Future<void> Function() ensureNotifications})` | Share entry, consent and permission order |
| `app/lib/features/trip/consent_flow.dart` | `ensureConsent({currentVersion, store, showSheet, postConsents})`, `ConsentResult` | Consent, LGPD |
| `app/lib/features/trip/permission_sheet.dart` | `PermissionGateway`, `LocationPermissionState`, `PermissionInfoSheet`, `PermissionDeniedSheet`, `PermissionBlockedSheet`, `LocationOffSheet` | Permission order, copy |
| `app/lib/features/trip/consent_sheet.dart` | `ConsentSheet.show(BuildContext)`, `ConsentChoice` | Prominent disclosure, LGPD |
| `app/lib/data/config/remote_config.dart` | `RemoteConfigRepository`, `RemoteConfig` (`minAppVersion`, `maintenance`, `messagePt`, `consentVersion`, `tileUrl`, `RemoteConfig.bundled`, `RemoteConfig.updateRequired`), `current()`, `refresh()` | Kill switch, min_app_version |
| `app/lib/data/prefs/theme_store.dart` | `ThemeStore.read()`, `write(ThemeMode)`, `themeModeKey` | User setting |
| `app/lib/features/settings/privacy_actions.dart` | `PrivacyActions({required api, tokenStore, consentStore})`, `deleteMyData()`, `revokeConsent()`, `DeleteOutcome` | Data-subject rights, LGPD |
| `app/lib/core/**` | `config/env.dart` (`apiBaseUrl`, `staticBaseUrl`, `fixAccuracyMaxM`), `errors/failures.dart` (`AppFailure`, `NetworkFailure`, `ServerFailure`, `StorageFailure`, `LocationFailure`, `Result`, `Ok`, `Err`), `geo/geo.dart` (`distM`, `BBox`, `decodePolyline`, `LatLng`, `earthRadiusM`, `degPerMeterLat`), `logging/log.dart` `Log` (`d`, `i`, `w`, `e`, `recent`), `net/backoff.dart` (`Backoff`, `backoffStepsS`, `backoffJitterS`), `time/clock.dart` (`Clock`, `SystemClock`, `FakeClock`), `config/contact.dart` (`supportEmail`, `policyUrl`, `termsUrl`) | Shared contracts, logging redaction |

### 2.2 Adapters already written, and the ones still missing

`app/lib/ui/adapters/` already contains six adapters that read the frozen
layer and produce the new view-models:

| Adapter | File | Public API |
|---|---|---|
| Lines | `lines_adapter.dart` | `LineVM lineVmOf(StaticLine line, {int liveCount = 0})`, `linesVmProvider`, `lineIndexProvider`, `lineByKeyProvider` (family by key), `timetableDateProvider` |
| Vehicles | `vehicles_adapter.dart` | `List<VehicleVM> orderVehicles(List<ClientVehicle> vehicles, String lineKey)`, `vehiclesVmProvider` (family by line id), `vehicleTickProvider` (5 s) |
| Arrivals | `arrivals_adapter.dart` | `ArrivalsSource`, `ArrivalQuery`, `TimetableArrivalsSource({required StaticLine line, required DateTime now})`, `arrivalsSourceProvider` (family by `StaticLine`), `nowProvider` |
| Trip | `trip_adapter.dart` | `TripVM tripVmOf(TripController controller)`, `String formatElapsed(int elapsedS)` |
| Clocks | `now_clock.dart` | `currentNowProvider`, `nowTickProvider`, `nowSecondTickProvider` |
| Local stores | `local_stores.dart` | `ShortcutsStore`, `RecentsStore`, `FavoritesStore`, `SettingsStore`, `SettingsNotifier`, `UiSettings`, `settingsProvider`; keys `ui_shortcuts_v1`, `ui_recents_v1`, `ui_favorites_v1`, `ui_data_saver_v1`, `ui_reduce_motion_v1` |

Still missing: a `Features` provider, a `RemoteConfig` to `Features` adapter
(gap 4), and a theme adapter that swaps `pontualLightTheme()` into
`main.dart`.

### 2.3 Reused as-is, no adapter

`BusApi` (through `busApiProvider`), `TokenStore`, `ConsentStore`,
`ConsentSheet.show`, `PermissionGateway` and the four permission sheets,
`shareTrip`, `TripController` construction with `TripDeps`,
`PrivacyActions`, `ThemeStore`, `RemoteConfigRepository`, `WebWakeLock` and
`ProdWebWakeLock`, `WebVisibilityTracker`, `InstallHintStore` and
`InstallHintSlot`, `WebTripBanner`, `EndCard`, `osmTileLayer`, `mapBounds`,
`tileUserAgent`, `userAgent()`, `Log`, `Clock`.

---

## 3. Reusable pieces

### 3.1 Providers in `app/lib/app/providers.dart`

```dart
final Provider<http.Client> httpClientProvider;                 // createHttpClient(), closed on dispose
final Provider<TokenStore> tokenStoreProvider;                  // const TokenStore()
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider;
class ThemeModeNotifier extends Notifier<ThemeMode> { void set(ThemeMode mode); }
final FutureProvider<String> timetableDateProvider;            // legacy, dd/MM/yyyy or ''
final Provider<BusApi> busApiProvider;
final FutureProvider<StaticDataRepository> staticDataRepoProvider;
final FutureProvider<List<StaticLine>> linesProvider;
final FutureProvider<LiveLines> liveProvider;
final FutureProvider<RemoteConfigRepository> remoteConfigRepoProvider;
final FutureProvider<String> tileUrlProvider;                   // OSM fallback
String wsBaseUrlOf(String api);
final Provider.autoDispose.family<VehicleRepository, int> vehicleRepoProvider;
```

Calls the new UI makes:

- `ref.watch(linesProvider)` -> `AsyncValue<List<StaticLine>>`
- `ref.watch(liveProvider)` -> `AsyncValue<LiveLines>`; each row is
  `[lineId, count]`
- `ref.watch(vehicleRepoProvider(lineId))` -> `VehicleRepository`;
  `start(lineId)` when the screen opens, `stop()` when it closes, then
  `repo.vehicles`, `repo.status`, `repo.evaluateAge()`
- `ref.watch(tileUrlProvider)` -> `AsyncValue<String>`
- `ref.read(busApiProvider)` for `PrivacyActions(api: ...)`
- `ref.read(remoteConfigRepoProvider.future)` then
  `(await repo.current()).consentVersion`
- `ref.read(themeModeProvider.notifier).set(mode)`

### 3.2 Data and domain (frozen, reached through adapters)

```dart
// app/lib/data/static_data/static_data.dart
class StaticLine {
  final int id; final String code; final String short; final String name;
  final bool pilot; final List<Map<String, dynamic>> schedules;
  final List<String> terminals; final List<String> areaTags; final bool isActive;
  factory StaticLine.fromJson(Map<String, dynamic> json);
}
class StaticDataRepository {
  const StaticDataRepository({required this.client, required this.staticBaseUrl,
    required this.bundleManifestJson, required this.bundleLinesJson,
    required this.prefs, required this.nowMs});
  Future<List<StaticLine>> lines();
  Future<Result<bool>> refresh();
}

// app/lib/data/realtime/vehicle_repository.dart
class ClientVehicle {
  final int id; final double lat; final double lng; final double? heading;
  final double kmh; final int members; final int ageS;
  factory ClientVehicle.fromRow(List<dynamic> row);
}
enum StreamStatus { connecting, live, stale, offline }
const int staleAfterS; // 45

// app/lib/domain/schedule.dart
enum DayType { weekday, saturday, sundayHoliday }
DayType dayTypeFor(DateTime local);
DateTime saoMateusTime(DateTime instant);
int minutesOf(String hhmm);
String? nextDeparture(List<String> times, int nowMinutes);
int minutesUntil(String hhmm, int nowMinutes);
Map<String, List<String>> groupByHour(List<String> times);

// app/lib/core/geo/geo.dart
double distM(double lat1, double lng1, double lat2, double lng2);
class BBox { bool contains(double lat, double lng); }
List<LatLng> decodePolyline(String text, [int precision = 5]); // core/geo LatLng

// app/lib/core/time/clock.dart
abstract class Clock { int nowMs(); int monotonicMs(); }
class SystemClock implements Clock {}
class FakeClock implements Clock { FakeClock([int startMs = 0]); void advance(int ms); }
```

`decodePolyline` returns `core/geo`'s own `LatLng`, so a route adapter must
convert to `latlong2.LatLng` before handing points to `flutter_map`.

### 3.3 Platform and trip (frozen, reused as-is)

```dart
// app/lib/platform/web/wake_lock.dart
abstract class WebWakeLock { Future<void> enable(); Future<void> disable(); Future<bool> get enabled; }
class ProdWebWakeLock implements WebWakeLock {}
class FakeWebWakeLock implements WebWakeLock {}

// app/lib/platform/web/visibility.dart
class WebVisibilityTracker { bool paused; void onHidden(int nowMs); void onVisible(); void check(int nowMs); int hiddenFor(int nowMs); }
bool webShouldPause(int hiddenForMs);

// app/lib/platform/web/web_banner.dart
class WebTripBanner { const WebTripBanner({this.paused = false, this.wakeUnsupported = false}); }

// app/lib/platform/web/user_agent.dart
String userAgent(); // '' off the web; BrowserFamily from ui/util/platform.dart

// app/lib/platform/web/install_hint.dart
bool shouldShowInstallHint({required bool isWeb, required bool isIos, required bool seen});
class InstallHintStore { Future<bool> seen(); Future<void> markSeen(); }
class InstallHintSlot { const InstallHintSlot({this.store = const InstallHintStore()}); }

// app/lib/platform/android/permission_gateway.dart
class GeolocatorPermissionGateway implements PermissionGateway {}
Future<void> ensureNotificationPermission();

// app/lib/features/settings/privacy_actions.dart
class PrivacyActions {
  const PrivacyActions({required this.api, this.tokenStore = const TokenStore(),
                        this.consentStore = const ConsentStore()});
  Future<DeleteOutcome> deleteMyData();
  Future<void> revokeConsent();
}

// app/lib/features/trip/trip_controller.dart, for the trip adapter
TripVM tripVmOf(TripController controller);
String formatElapsed(int elapsedS);
```

### 3.4 Already-built new-UI pieces

| Piece | Path | Public API |
|---|---|---|
| Certainty | `app/lib/ui/models/certainty.dart` | `Certainty`, `liveFreshS`, `certaintyForAge`, `certaintyRank`, `isMeasured`, `certaintyLabelKeys` |
| View-models | `app/lib/ui/models/` | `LineVM`, `ArrivalVM`, `VehicleVM`, `ShortcutVM`, `ShortcutKind`, `TripPhase`, `TripVM` |
| Flags | `app/lib/ui/models/features.dart` | `Features`, `Features.fromJson`, `Features.copyWith` |
| Colour tokens | `app/lib/ui/design/tokens/colors.dart` | `PontualColors.light` / `.dark`, `graphicOf`, `textOf`, `copyWith`, `lerp`, `CertaintyTone` |
| Text tokens | `app/lib/ui/design/tokens/text.dart` | `PontualText` (8 styles plus `clock`), `pontualFontFamily`, `weightAxis` |
| Theme | `app/lib/ui/design/theme/theme.dart` | `pontualLightTheme()`, `pontualDarkTheme()` |
| Context accessors | `app/lib/ui/design/theme/context.dart` | `context.colors`, `context.text`, `PontualTextStyles` |
| Spacing and sizes | `app/lib/ui/design/tokens/spacing.dart` | `Space`, `Breakpoint`, `Breakpoint.of`, `marginFor`, `Radii`, `hitTarget`, `Sizes` |
| Motion | `app/lib/ui/design/tokens/motion.dart` | `Motion`, `MotionCurves`, `motionDuration` |
| Line colours | `app/lib/ui/design/tokens/line_colors.dart` | `linePaletteLight`, `linePaletteDark`, `paletteOf`, `stableHash`, `lineColorOf`, `lineBadgeTextOf`, `parseHexColor` |
| Contrast maths | `app/lib/ui/util/contrast.dart` | `relativeLuminance`, `contrastRatio`, `bestTextOn`, `ensureContrast` |
| ETA formatting | `app/lib/ui/util/format_eta.dart` | `EtaFormat`, `formatEta`, `minutesUntilClock`, `formatHours`, `formatClock`, `isStaleArrival`, `hourLabelOf`, `minuteOf` |
| Search index | `app/lib/ui/util/search_index.dart` | `normalizeText`, `LineIndex`, `buildLineIndex`, `searchLines`, `LineMatch`, `MatchRank`, `matchesAllTokens`, `highlightRanges` |
| Haptics and platform | `app/lib/ui/util/platform.dart` | `Haptics`, `PlatformInfo`, `BrowserFamily`, `browserFamilyOf` |
| Strings | `app/lib/ui/strings/ui_strings.dart` | `UiStrings`, 10 sections: navigation and shell, certainty, home, search screen, lines screen, line screen, timetable, trip flow, settings/privacy/about, system states |
| Font | `app/assets/fonts/Manrope.ttf` + `tools/build_fonts/subset_manrope.py` | 51712 bytes, subset to Latin plus the arrows and punctuation in the copy, `tnum` and `kern` kept, script fails above the 70 KB budget |

---

## 4. Baseline metrics

### 4.1 What UI_SPEC demands

UI_SPEC 2.1 lists the budgets and says the stricter of the spec budget and
the U01 baseline wins.

| Metric (UI_SPEC 2.1) | Budget | Measurable on this machine? | Command to run later |
|---|---|---|---|
| Time to first frame, release cold | no worse than baseline +10 % | Not measured, and no baseline exists in the repo. Needs a device or an emulator: `adb devices` is empty, the emulator binary and one AVD (`Medium_Phone_API_37.0`) exist but were not started, and no APK is installed. | `flutter run --profile --trace-startup`, or install a release APK and run `adb shell am start -W -n com.spotnik.pontual/.MainActivity`. `PLAN.md` (T20) claims a cold start was measured but records no number, and `docs/field-tests/budgets.md` lists it as TODO, so treat the baseline as absent. |
| Android size delta | <= +400 KB over baseline | Not measured, and the baseline does not exist. `flutter` 3.47.6 is at `/home/edubot/flutter` (`.fvmrc`) and `/home/edubot/Android/Sdk` is set in `app/android/local.properties`, so the measurement is possible; no build was run for this audit. | `cd app && flutter build apk --release --analyze-size` and `flutter build appbundle --release --analyze-size`. Record the byte counts here as the baseline. |
| Web initial transfer delta | <= +120 KB over baseline | Not measured. The only in-repo figure is from 2026-10-03 (`docs/field-tests/budgets.md`): JS path 2.95 MB gz, wasm path 3.08 MB gz, against the 3 MB PLAN.md budget. A 120 KB allowance is therefore nearly the whole remaining headroom. | `cd app && flutter build web --release --no-web-resources-cdn` then `gzip -c build/web/main.dart.js \| wc -c`. `flutter build web --release --analyze-size` is the supported shortcut. |
| Frame time p95 build and raster | < 8 ms | No: needs profile mode on hardware. | `flutter run --profile` plus DevTools Performance, or the debug-only `SchedulerBinding.instance.addTimingsCallback` logger from UI_SPEC 11.4. |
| Map pan and zoom | >= 55 fps, >= 90 % of frames | No: needs hardware. | Same as above while panning and zooming the line map. |
| Memory on the line screen | <= baseline +15 MB | No: needs hardware. | DevTools Memory with the line screen open. |
| Idle CPU on Home | ~0 %, no ticker | Partially, by inspection: `app/lib/features/home/home_screen.dart` arms `Timer.periodic(60 s)` to refresh `liveProvider`, so the current UI does not meet this. The new layer has `nowTickProvider` but no screen consumes it yet. | DevTools CPU on Home, plus a widget test asserting no pending timers. |
| Interaction latency | < 100 ms | No: needs hardware timing. | DevTools, or timings logged around taps during a profile run. |
| Data: no new network calls from the UI layer | none | Yes, by inspection: nothing under `app/lib/ui/**` imports `package:http`, and the only callers are `app/lib/app/providers.dart` and the frozen data layer. | A test that fails if `app/lib/ui/**` imports `package:http`. |

`PLAN.md` 10.1 budgets, for cross-reference: Android AAB <= 15 MB arm64,
universal APK <= 25 MB, web first load <= 3 MB compressed and repeat
<= 0.2 MB, first frame <= 2 s mid-range and 3.5 s low-end, RAM <= 150 MB
with the map visible and 80 MB on the trip screen, trip CPU average < 2 %,
build and raster p95 < 8 ms, map pan >= 55 fps. `docs/field-tests/budgets.md`
already measured ping wire size, leader and follower data and web first
load on 2026-10-03; every other row is TODO there.

### 4.2 What was measured for this audit

Nothing. No build, no emulator run, no profiling. The only numbers quoted
above are the ones already recorded in `docs/field-tests/budgets.md`, and
they are labelled as such. The font size (51712 bytes) is a file size read
from disk, not a build measurement. Run the commands in 4.1 and fill in the
baseline before the first new UI screen lands, because every budget in
UI_SPEC 2.1 is expressed as a delta against it.

---

## 5. Gaps and risks

Numbered for reference from the implementing tasks. Items marked **closed**
were open when the audit started and were resolved by the parallel change
that landed during the audit; they stay listed because the decisions behind
them still need an ADR or a test.

1. **Bundled font, now present.** `app/assets/fonts/Manrope.ttf` is 51712
   bytes, `app/pubspec.yaml` declares family `Manrope` with that single
   variable file, and `tools/build_fonts/subset_manrope.py` regenerates it
   with fonttools and fails above 70 KB. The `fonts:` block only lists
   `weight: 400`, which is fine because `PontualText` drives `wght` through
   `FontVariation`. Remaining risk: the size counts against the +400 KB
   Android budget and the +120 KB web budget, so the U01 size measurement in
   4.1 must be taken before more assets are added. No ADR is recorded in
   `DECISIONS.md` yet.

2. **`StaticLine` gained `terminals`, `areaTags` and `isActive`.** The parser
   now reads `terminals` and `area_tags` through a `_stringsOf` helper that
   drops unknown value types, and `is_active` defaults to `true`. This is
   additive and keeps old bundles parseable, so the load path is unchanged.
   Remaining risk: `is_active` is parsed but nothing filters on it, so a
   retired line would still render. The lines screen should hide
   `isActive == false` entries, and AGENTS.md requires that removing a line
   means `is_active: false` rather than a reused id.

3. **Manifest `routes` is empty, so there is no route data.**
   `app/assets/data/manifest.json` has `"routes": {}`, `data/routes/` and
   `build/routes/` are empty, and `PontualMapWithMarkers` always passes
   `route = const <LatLng>[]`. `Features.routeLine` is correctly `false`.
   `core/geo.decodePolyline` returns `core/geo.LatLng`, not `latlong2.LatLng`,
   so an adapter needs a conversion. Handling: keep the flag off; add the
   conversion when route data lands.

4. **`RemoteConfig` has no feature flags.** `app/assets/data/config.json`
   carries only `min_app_version`, `maintenance`, `message_pt`,
   `consent_version`, `tile_url`, and `RemoteConfig.fromJson` has no
   `features` key. `Features.fromJson` therefore has no remote source and
   always returns compile-time defaults, and no Riverpod provider exposes
   `Features` at all. Handling: add a `featuresProvider` reading the bundled
   defaults, then decide whether the remote object is worth the
   static-data-contract change.

5. **Two strings files, and new pt-BR literals outside them.**
   `app/lib/app/strings_pt.dart` (`StringsPt`) serves the live app;
   `app/lib/ui/strings/ui_strings.dart` (`UiStrings`) serves the new layer.
   Legacy screens still hard-code copy (`'Linha não encontrada.'` in
   `app/lib/features/line/line_screen.dart`, the disclosure body in
   `app/lib/features/trip/consent_sheet.dart`, `'Desci - encerrar viagem'`
   in `app/lib/features/trip/trip_screen.dart`). Worse, the new
   `TripVM.dockMessage` in `app/lib/ui/models/trip_vm.dart` returns pt-BR
   literals instead of reading `UiStrings`. Handling: move those four
   strings into `UiStrings` and have the model expose a key or a label
   parameter; record an ADR so the two files do not drift.

6. **Router and route keys.** Live routes are `/welcome` (the initial
   location, so the app opens on a placeholder), `/`, `/line/:id` (integer
   id), `/trip` (needs `state.extra is TripController`), `/settings`,
   `/privacy` (+ `policy`, `terms`), `/about`, `/system`. Missing:
   `/search`, `/lines`, `/line/:key` with `?tab=`, `/system/:kind`, a
   not-found route and `/_gallery`. `lineByKeyProvider` already exists for
   key lookups, so the route is the only missing piece. Handling: build the
   new router in `app/lib/ui/` next to the old one and switch behind
   `--dart-define=NEW_UI=true` (UI_SPEC 0.1 rule 3).

7. **No shell, so no navigation, dock host, banner slot or toast slot.**
   `AdaptiveScaffold`, the bottom navigation and the route transitions do
   not exist, even though `BannerSlot`, `ToastSlot`, `TripDock`, `Breakpoint`
   and `marginFor` are all ready. Handling: the next task is a shell that
   composes them.

8. **No feature screens.** `app/lib/ui/features/` does not exist. Home,
   search, lines list, line detail with its sheet, the timetable tab, the
   trip screen and the settings screens are all still the legacy widgets.

9. **No gallery route and no tests for the new layer.** `app/test/` has 26
   Dart files, all against the legacy screens; `app/lib/ui/**` has none.
   `/_gallery` does not exist, so there is no light/dark and 1.0/2.0 text
   scale QA surface. Handling: each component lands with a test and the
   gallery is compiled out of release with a `kDebugMode` guard.

10. **`contrast_test.dart` does not exist** even though
    `app/lib/ui/design/tokens/colors.dart` says the hex values are the ones
    that pass it, and UI_SPEC 4.1 and 12.6 require it. The palette values
    were adjusted relative to the spec table (`inkSubtle`, `live`,
    `warning`, `scrim`, `mapScrim`), so the proof must be written before the
    values are treated as final.

11. **Map gaps against UI_SPEC 7.5.** No `mapScrim` tint, no attribution
    chip, no follow mode, no zoom controls, no recenter rule, no marker cap
    with a sheet summary, no deferred import. `PontualMap` is not used by
    `MapTab` at all, only by `app/test/map_test.dart`. Camera fit is
    `initialCenter` and `initialZoom` only. Handling: build the map layer in
    `app/lib/ui/features/line/map/` over the frozen `osmTileLayer`,
    `mapBounds` and `tileUserAgent`.

12. **`decodePolyline` type mismatch** (gap 3) and
    `PontualMapWithMarkers.route` is declared but never fed.

13. **Trip end card and kudos.** `EndCard` shows a reason and one button
    with no stroke animation and no local counter.
    `UiStrings.kudosPrefix` and `kudosSuffix` exist, but `Features` has no
    `localKudos` field, so the flag UI_SPEC 7.7 assumes is missing.

14. **`TripDock` and `TripVM` are not wired to the trip controller.**
    `tripVmOf(TripController)` exists but nothing creates a provider from
    it, and `TripDock` has no host. The dock also has no contextual
    "Estou neste ônibus" label for a shareable line screen, and no line
    chooser sheet exists for the unbound case.

15. **Web permission states.** `PermissionCard` and `PermissionCardState`
    exist and `userAgent()` plus `browserFamilyOf` can pick the right
    unblocking copy, but no screen composes them, and `permission_sheet.dart`
    still only covers the geolocator path. `UiStrings.alreadyAllowed` and the
    four `unblock*` strings are already in place.

16. **`Features` has no `localKudos` flag** (gap 13) and no provider at all
    (gap 4). A disabled feature must render nothing, so every component for
    an off feature needs a flag check at the call site.

17. **No `PontualSpacing` or `PontualMotion` ThemeExtension.** Only colours
    and text are extensions; spacing, radii, sizes and durations are
    constants and free functions in `app/lib/ui/design/tokens/`. That
    matches UI_SPEC 4.7, which only mandates extensions for colours and
    text, but it is worth stating so it is not rediscovered as a bug.

18. **`lineColorOf` needs a `lineKey`, and the data layer has two
    identifiers.** `LineVM.key` is documented as "the immutable line code
    when present, the id otherwise", and `lineVmOf` is the only place that
    decides. Fixing one convention (`StaticLine.code`) in `lineVmOf` and
    using it everywhere prevents badge colours from changing when the
    fallback path is taken.

19. **UI_SPEC.md is truncated at section 13.5.** Sections 14 to 18 are
    listed in the table of contents but absent from the body, including
    section 16 (the task list) and section 17 (the measurement protocol).
    This audit maps sections 5, 6 and 7 only. Handling: ask the owner for the
    remaining sections before planning any numbered task against them.

20. **Nothing in `app/lib/ui/**` is wired or compiled.** No file outside
    that directory imports it, `main.dart`, `router.dart` and `app/theme.dart`
    are untouched, and `flutter analyze` has not been run over the new code
    in this audit. The design-system layer may still contain analyzer or
    test failures. Handling: run `flutter analyze` and `flutter test` from
    `app/` as the first step of the next task.

## Addendum 2026-10-11: build complete, cutover done

The UI described as "not wired" above is finished and the old UI is
removed. Status of this document's open items:

- Sections 1-3 (UI map, frozen files, reusable pieces): the map now
  resolves to `app/lib/ui/` reading the same data layer through
  `app/lib/ui/adapters/`. `main.dart` boots the new router directly; the
  `NEW_UI` flag is gone.
- Baseline metrics (section 4): no Android device is attached to this
  host, so cold start, frame times and memory are still unmeasured (see
  `docs/field-tests/budgets.md` for the device protocol). Release sizes
  measured on this host on 2026-10-11: web `main.dart.js` 950 KB gz,
  bundled Manrope subset 50.5 KB (budget 70 KB), CanvasKit 36.1 MB
  uncompressed (standard Flutter payload, cached and compressed in
  practice). Release AAB (arm64-v8a, armeabi-v7a, x86_64, obfuscated)
  is 52.3 MB, the new size baseline; UI_SPEC delta budgets apply from
  here. (`flutter build apk --analyze-size` refuses multi-ABI analysis;
  the AAB is the shippable artifact CI builds.)
- Gaps: `TripVM.dockMessage` hard-coding is fixed (labels come from
  `UiStrings`); UI_SPEC sections 14-18 arrived only as wireframes and
  section 7, which were used as the copy deck (see DECISIONS.md D-U01).
- Verification at cutover: `flutter analyze` clean, `dart format` clean,
  full `flutter test` green (228 tests, up from 188 on the old tree),
  manifest source audit passes, `flutter build web --release` succeeds.
  Gitleaks is not installed on this host; the secret scan runs in CI.

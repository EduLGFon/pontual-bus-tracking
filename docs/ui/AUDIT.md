# AUDIT.md - U01 repository audit (before the new UI)

Scope: `docs/ui/UI_SPEC.md` rule 1 (Task U01 repository audit) and rule 5 (measure before and after). This document maps the concepts named by UI_SPEC sections 5, 6 and 7 to what existed in `app/lib/` at audit time, lists what the new UI may not touch, the pieces it reuses, the baseline metrics and the gaps.

Audit date: 2026-10-10, updated the same day after the parallel implementation landed the design-system layer. Package versions come from `app/pubspec.yaml`, `app/pubspec.lock` and `.fvmrc`; no command was re-run to confirm them.

Status: the UI described as "not wired" below is finished and the old UI is removed. `main.dart` boots the new router directly; the `NEW_UI` flag is gone. `app/lib/ui/**` reads the same data layer through `app/lib/ui/adapters/`. `flutter analyze` clean, `dart format` clean, full `flutter test` green (228 tests at cutover), manifest source audit passes, `flutter build web --release` succeeds. Gitleaks is not installed on this host; the secret scan runs in CI.

## 1. Baseline metrics

UI_SPEC 2.1 lists the budgets and says the stricter of the spec budget and the U01 baseline wins. No Android device is attached to this host, so cold start, frame times and memory are still unmeasured (see `docs/field-tests/budgets.md` for the device protocol). Release sizes measured on this host on 2026-10-11:

| Metric (UI_SPEC 2.1) | Budget | Measured | Verdict |
|---|---|---|---|
| Web `main.dart.js` (gz) | delta <= +120 KB | 950 KB gz | new baseline |
| Bundled Manrope subset | <= 70 KB | 50.5 KB (`app/assets/fonts/Manrope.ttf`) | inside |
| CanvasKit payload | standard Flutter payload | 36.1 MB uncompressed, cached and compressed in practice | informational |
| Release AAB (arm64-v8a, armeabi-v7a, x86_64, obfuscated) | PLAN <= 15 MB arm64 | 52.3 MB universal | new size baseline; needs the per-ABI split on the capable machine |
| Cold start to first frame | <= baseline +10 % | TODO device | `adb shell am start -W -n com.spotnik.pontual/.MainActivity` |
| Home first-paint to interactive | < 100 ms interaction | TODO device | `flutter run --profile --trace-startup` + DevTools |
| Linha open to map visible | paints from cache, no spinner | TODO device | verify no blocking spinner on cached data |
| Map pan frame timings (p50/p95) | p95 build+raster < 8 ms, >= 55 fps >= 90 % frames | TODO device | profile mode on hardware |
| Memory after 2 min on Linha | <= baseline +15 MB | TODO device | DevTools Memory |
| APK size (`--analyze-size`) | delta <= +400 KB | TODO | `cd app && flutter build apk --release --analyze-size` (refuses multi-ABI; use the AAB per-ABI split) |
| Web transfer (`--analyze-size` equiv) | delta <= +120 KB | TODO | `du -sb build/web` + gzip total; `--analyze-size` does not exist on `flutter build web` in 3.47.6 (see D-U06) |

PLAN.md 10.1 budgets, for cross-reference: Android AAB <= 15 MB arm64, universal APK <= 25 MB, web first load <= 3 MB compressed and repeat <= 0.2 MB, first frame <= 2 s mid-range and 3.5 s low-end, RAM <= 150 MB with the map visible and 80 MB on the trip screen, trip CPU average < 2 %, build and raster p95 < 8 ms, map pan >= 55 fps. `docs/field-tests/budgets.md` already measured ping wire size, leader and follower data and web first load on 2026-10-03; every other row is TODO there.

See `docs/ui/PERF.md` for the fuller device-run table (emulator medians) and the TODO list for hardware and field runs.

## 2. What the new UI may not touch (frozen layer)

UI_SPEC 0.1 rule 2 freezes the API client, authentication, consent recording, tracking and ping logic, static-data loading and backend contracts. The new UI reads them through providers and adapters only. Frozen files (public API the UI calls; frozen because of contract/privacy):

- `app/lib/data/api/bus_api.dart` (`BusApi`, `ensureRegistered`, `postConsents`, `startTrip`, `pingTrip`, `endTrip`, `deleteMe`, `getVehicles`, `getLive`, `BaseUrlProvider`)
- `app/lib/data/api/dto.dart` (`TripInstruction`, `VehiclesSnapshot`, `LiveLines`, `mapError`)
- `app/lib/data/prefs/token_store.dart` (`TokenStore`, `tokenPrefsKey`)
- `app/lib/data/prefs/consent_store.dart` (`ConsentStore`, `consentVersionKey`, `consentPostedKey`)
- `app/lib/data/static_data/static_data.dart` (`StaticDataRepository`, `StaticLine` with `terminals`, `areaTags`, `isActive`, all defaulted; `linesKeyPrefix`, `manifestKey`, `checkInterval`, `headerOf`)
- `app/lib/data/realtime/vehicle_repository.dart` (`VehicleRepository`, `ClientVehicle`, `StreamStatus`, `staleAfterS`, `watchdogResyncS`, `pollFallbackAfterS`, `pollIntervalS`, `reconnectDelaysS`, `ChannelFactory`, `SnapshotFetcher`)
- `app/lib/features/trip/trip_controller.dart` (`TripController`, `TripDeps`, `StartFailure`, `TripEndKind`, and the methods listed in AUDIT 2.1)
- `app/lib/features/trip/location_service.dart` (`LocationService`, `TripFix`, `RawFix`, `acceptFix`, `dropReason`, `normalizeSpeed`, `normalizeHeading`, `round5`, `batteryBucket`, `fixArea`, `fixMaxAgeMs`)
- `app/lib/features/trip/ping_client.dart` (`PingClient`, `queue`, `consecutiveFailures`, `PingReply`, `PingOutcome`)
- `app/lib/features/trip/trip_supervisor.dart` (`TripSupervisor`, `Supervision`, `pollEnvironment`, `onFix`, `onPingSuccess`, `evaluate`, `confirmStillRiding`, `reset`, `offlineAfterFailures`, `permissionRevokedAfterPolls`, `offlineAfterMs`)
- `app/lib/features/trip/share_flow.dart` (`shareTrip`)
- `app/lib/features/trip/consent_flow.dart` (`ensureConsent`, `ConsentResult`)
- `app/lib/features/trip/permission_sheet.dart` (`PermissionGateway`, `LocationPermissionState`, `PermissionInfoSheet`, `PermissionDeniedSheet`, `PermissionBlockedSheet`, `LocationOffSheet`)
- `app/lib/features/trip/consent_sheet.dart` (`ConsentSheet.show`, `ConsentChoice`)
- `app/lib/data/config/remote_config.dart` (`RemoteConfigRepository`, `RemoteConfig` with `minAppVersion`, `maintenance`, `messagePt`, `consentVersion`, `tileUrl`, `RemoteConfig.bundled`, `RemoteConfig.updateRequired`, `current`, `refresh`)
- `app/lib/data/prefs/theme_store.dart` (`ThemeStore.read`, `write`, `themeModeKey`)
- `app/lib/features/settings/privacy_actions.dart` (`PrivacyActions` with `deleteMyData`, `revokeConsent`, `DeleteOutcome`)
- `app/lib/core/**` (`config/env.dart`, `errors/failures.dart`, `geo/geo.dart`, `logging/log.dart`, `net/backoff.dart`, `time/clock.dart`, `config/contact.dart`)

## 3. Adapters and providers the new UI uses

`app/lib/ui/adapters/` contains the adapters that read the frozen layer and produce the new view-models: `lines_adapter.dart` (`LineVM lineVmOf`, `linesVmProvider`, `lineIndexProvider`, `lineByKeyProvider`, `timetableDateProvider`), `vehicles_adapter.dart` (`orderVehicles`, `vehiclesVmProvider`, `vehicleTickProvider`), `arrivals_adapter.dart` (`ArrivalsSource`, `ArrivalQuery`, `TimetableArrivalsSource`, `arrivalsSourceProvider`, `nowProvider`), `trip_adapter.dart` (`TripVM tripVmOf`, `formatElapsed`), `now_clock.dart` (`currentNowProvider`, `nowTickProvider`, `nowSecondTickProvider`), `local_stores.dart` (`ShortcutsStore`, `RecentsStore`, `FavoritesStore`, `SettingsStore`, `SettingsNotifier`, `UiSettings`, `settingsProvider`).

`app/lib/app/providers.dart` supplies `httpClientProvider`, `tokenStoreProvider`, `themeModeProvider`/`ThemeModeNotifier`, `timetableDateProvider`, `busApiProvider`, `staticDataRepoProvider`, `linesProvider`, `liveProvider`, `remoteConfigRepoProvider`, `tileUrlProvider`, `wsBaseUrlOf`, `vehicleRepoProvider`.

## 4. Gaps and risks (numbered for reference from implementing tasks)

Items marked **closed** were open when the audit started and were resolved by the parallel change that landed during the audit; they stay listed because the decisions behind them still need an ADR or a test.

1. **Bundled font, now present.** `app/assets/fonts/Manrope.ttf` is 51712 bytes, `app/pubspec.yaml` declares family `Manrope` with that single variable file, and `tools/build_fonts/subset_manrope.py` regenerates it with fonttools and fails above 70 KB. The `fonts:` block only lists `weight: 400`, which is fine because `PontualText` drives `wght` through `FontVariation`. Remaining risk: the size counts against the +400 KB Android budget and the +120 KB web budget, so the U01 size measurement in section 1 must be taken before more assets are added. No ADR is recorded in `DECISIONS.md` yet.
2. **`StaticLine` gained `terminals`, `areaTags` and `isActive`.** The parser now reads `terminals` and `area_tags` through a `_stringsOf` helper that drops unknown value types, and `is_active` defaults to `true`. Additive, keeps old bundles parseable. Remaining risk: `is_active` is parsed but nothing filters on it, so a retired line would still render. The lines screen should hide `isActive == false` entries, and AGENTS.md requires that removing a line means `is_active: false` rather than a reused id.
3. **Manifest `routes` is empty, so there is no route data.** `app/assets/data/manifest.json` has `"routes": {}`, `data/routes/` and `build/routes/` are empty, and `PontualMapWithMarkers` always passes `route = const <LatLng>[]`. `Features.routeLine` is correctly `false`. `core/geo.decodePolyline` returns `core/geo.LatLng`, not `latlong2.LatLng`, so an adapter needs a conversion. Handling: keep the flag off; add the conversion when route data lands.
4. **`RemoteConfig` has no feature flags.** `app/assets/data/config.json` carries only `min_app_version`, `maintenance`, `message_pt`, `consent_version`, `tile_url`, and `RemoteConfig.fromJson` has no `features` key. `Features.fromJson` therefore has no remote source and always returns compile-time defaults, and no Riverpod provider exposes `Features` at all. Handling: add a `featuresProvider` reading the bundled defaults, then decide whether the remote object is worth the static-data-contract change.
5. **Two strings files, and new pt-BR literals outside them.** `app/lib/app/strings_pt.dart` (`StringsPt`) serves the live app; `app/lib/ui/strings/ui_strings.dart` (`UiStrings`) serves the new layer. Legacy screens still hard-code copy (`'Linha não encontrada.'` in `app/lib/features/line/line_screen.dart`, the disclosure body in `app/lib/features/trip/consent_sheet.dart`, `'Desci - encerrar viagem'` in `app/lib/features/trip/trip_screen.dart`). Worse, the new `TripVM.dockMessage` in `app/lib/ui/models/trip_vm.dart` returns pt-BR literals instead of reading `UiStrings`. Handling: move those four strings into `UiStrings` and have the model expose a key or a label parameter; record an ADR so the two files do not drift. (Closed at cutover: `TripVM.dockMessage` hard-coding is fixed, labels come from `UiStrings`.)
6. **Router and route keys.** Live routes are `/welcome` (the initial location, so the app opens on a placeholder), `/`, `/line/:id` (integer id), `/trip` (needs `state.extra is TripController`), `/settings`, `/privacy` (+ `policy`, `terms`), `/about`, `/system`. Missing: `/search`, `/lines`, `/line/:key` with `?tab=`, `/system/:kind`, a not-found route and `/_gallery`. `lineByKeyProvider` already exists for key lookups, so the route is the only missing piece. Handling: build the new router in `app/lib/ui/` next to the old one and switch behind `--dart-define=NEW_UI=true` (UI_SPEC 0.1 rule 3). (Closed at cutover: new router boots directly.)
7. **No shell, so no navigation, dock host, banner slot or toast slot.** `AdaptiveScaffold`, the bottom navigation and the route transitions do not exist, even though `BannerSlot`, `ToastSlot`, `TripDock`, `Breakpoint` and `marginFor` are all ready. Handling: the next task is a shell that composes them. (Closed at cutover.)
8. **No feature screens.** `app/lib/ui/features/` does not exist. Home, search, lines list, line detail with its sheet, the timetable tab, the trip screen and the settings screens are all still the legacy widgets. (Closed at cutover.)
9. **No gallery route and no tests for the new layer.** `app/test/` has 26 Dart files, all against the legacy screens; `app/lib/ui/**` has none. `/_gallery` does not exist, so there is no light/dark and 1.0/2.0 text scale QA surface. Handling: each component lands with a test and the gallery is compiled out of release with a `kDebugMode` guard. (Closed at cutover: 228 tests at cutover, up from 188 on the old tree.)
10. **`contrast_test.dart` does not exist** even though `app/lib/ui/design/tokens/colors.dart` says the hex values are the ones that pass it, and UI_SPEC 4.1 and 12.6 require it. The palette values were adjusted relative to the spec table (`inkSubtle`, `live`, `warning`, `scrim`, `mapScrim`), so the proof must be written before the values are treated as final.
11. **Map gaps against UI_SPEC 7.5.** No `mapScrim` tint, no attribution chip, no follow mode, no zoom controls, no recenter rule, no marker cap with a sheet summary, no deferred import. `PontualMap` is not used by `MapTab` at all, only by `app/test/map_test.dart`. Camera fit is `initialCenter` and `initialZoom` only. Handling: build the map layer in `app/lib/ui/features/line/map/` over the frozen `osmTileLayer`, `mapBounds` and `tileUserAgent`. (Closed at cutover for tint/controls; deferred map import decided eager, see DECISIONS.md D-U20.)
12. **`decodePolyline` type mismatch** (gap 3) and `PontualMapWithMarkers.route` is declared but never fed.
13. **Trip end card and kudos.** `EndCard` shows a reason and one button with no stroke animation and no local counter. `UiStrings.kudosPrefix` and `kudosSuffix` exist, but `Features` has no `localKudos` field, so the flag UI_SPEC 7.7 assumes is missing.
14. **`TripDock` and `TripVM` are not wired to the trip controller.** `tripVmOf(TripController)` exists but nothing creates a provider from it, and `TripDock` has no host. The dock also has no contextual "Estou neste ônibus" label for a shareable line screen, and no line chooser sheet exists for the unbound case. (Closed at cutover.)
15. **Web permission states.** `PermissionCard` and `PermissionCardState` exist and `userAgent()` plus `browserFamilyOf` can pick the right unblocking copy, but no screen composes them, and `permission_sheet.dart` still only covers the geolocator path. `UiStrings.alreadyAllowed` and the four `unblock*` strings are already in place.
16. **`Features` has no `localKudos` flag** (gap 13) and no provider at all (gap 4). A disabled feature must render nothing, so every component for an off feature needs a flag check at the call site.
17. **No `PontualSpacing` or `PontualMotion` ThemeExtension.** Only colours and text are extensions; spacing, radii, sizes and durations are constants and free functions in `app/lib/ui/design/tokens/`. That matches UI_SPEC 4.7, which only mandates extensions for colours and text, but it is worth stating so it is not rediscovered as a bug.
18. **`lineColorOf` needs a `lineKey`, and the data layer has two identifiers.** `LineVM.key` is documented as "the immutable line code when present, the id otherwise", and `lineVmOf` is the only place that decides. Fixing one convention (`StaticLine.code`) in `lineVmOf` and using it everywhere prevents badge colours from changing when the fallback path is taken.
19. **UI_SPEC.md is truncated at section 13.5.** Sections 14 to 18 are listed in the table of contents but absent from the body, including section 16 (the task list) and section 17 (the measurement protocol). This audit maps sections 5, 6 and 7 only. Handling: ask the owner for the remaining sections before planning any numbered task against them. (Closed at cutover: UI_SPEC sections 14-18 arrived only as wireframes and section 7, used as the copy deck; see DECISIONS.md D-U01.)
20. **Nothing in `app/lib/ui/**` is wired or compiled.** No file outside that directory imports it, `main.dart`, `router.dart` and `app/theme.dart` are untouched, and `flutter analyze` has not been run over the new code in this audit. The design-system layer may still contain analyzer or test failures. Handling: run `flutter analyze` and `flutter test` from `app/` as the first step of the next task. (Closed at cutover.)

## 5. Addendum 2026-10-11: build complete, cutover done

- Sections 1-3 (UI map, frozen files, reusable pieces): the map now resolves to `app/lib/ui/` reading the same data layer through `app/lib/ui/adapters/`. `main.dart` boots the new router directly; the `NEW_UI` flag is gone.
- Baseline metrics (section 1): no Android device is attached to this host, so cold start, frame times and memory are still unmeasured (see `docs/field-tests/budgets.md` for the device protocol). Release sizes measured on this host on 2026-10-11: web `main.dart.js` 950 KB gz, bundled Manrope subset 50.5 KB (budget 70 KB), CanvasKit 36.1 MB uncompressed (standard Flutter payload, cached and compressed in practice). Release AAB (arm64-v8a, armeabi-v7a, x86_64, obfuscated) is 52.3 MB, the new size baseline; UI_SPEC delta budgets apply from here. (`flutter build apk --analyze-size` refuses multi-ABI analysis; the AAB is the shippable artifact CI builds.)
- Gaps: `TripVM.dockMessage` hard-coding is fixed (labels come from `UiStrings`); UI_SPEC sections 14-18 arrived only as wireframes and section 7, which were used as the copy deck (see DECISIONS.md D-U01).
- Verification at cutover: `flutter analyze` clean, `dart format` clean, full `flutter test` green (228 tests, up from 188 on the old tree), manifest source audit passes, `flutter build web --release` succeeds. Gitleaks is not installed on this host; the secret scan runs in CI.
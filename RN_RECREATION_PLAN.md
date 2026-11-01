# RN Recreation Plan: Pontual (Flutter -> React Native / Expo)

Status: draft for implementation. Working directory: `rn/`. Source of truth for product/design: root `PLAN.md`, `DECISIONS.md`, `AGENTS.md`. This plan adapts every Flutter feature, screen, component, domain rule, and platform behavior to React Native (Expo) without omissions.

Rules for execution:
- One task per PR. Do not start the next task until acceptance criteria pass.
- Run `npx tsc --noEmit`, `npx expo lint`, and relevant tests after each task.
- Never weaken security, privacy, or budgets for convenience.
- All user-visible strings in pt-BR; code/comments/docs in English.
- No em dashes in any artifact.

## 0. Baseline and gap summary

Current RN scaffold (`rn/`) has:
- Expo Router routes: `index`, `line/[id]`, `trip`, `settings`, `privacy`.
- Core/data modules: env, failures, geo, log, backoff, clock, busApi (partial), dto (zod), remoteConfig, learningRepository (partial), prefs (consent/token/theme/storage), realtime vehicleRepository (partial), staticData (partial).
- Domain: report, autoEnd, tripState (partial).
- Features: map (web/native split), reports (reportActions), trip (permissionGateway, tripService partial).
- UI: Map components, MapProps.
- Stores: zustand index.

Major gaps vs Flutter:
- Missing design system (tokens, theme, 36 components, 4 icons).
- Missing shell (app shell, bottom nav, dock host, offline bridge, toast host, trip host).
- Missing adapters and view models.
- Missing most screens and flows (Welcome, Home parity, Line tabs, Timetable, Share-trip consent sheet, Permission education, Trip active/ended, Settings sections, Privacy center, About, System screens, Offline banner, Reports full UI, Search/place search, Gallery/dev).
- Missing trip domain completeness (sampling policy, share phases, sharing health, auto-end, consent flow, location service, ping client, trip controller/supervisor, share progress, metrics).
- Missing learning domain models and ETA UI.
- Missing platform modules (Android battery optimization, GNSS quality, notification permission, permission gateway; web download hint, install hint, user agent, visibility, wake lock, web banner).
- Missing Android foreground service strategy for RN.
- Missing diagnostics uploader.
- Missing tests (unit, integration, security).
- Missing CI/CD and release configuration.

## 1. Parity inventory (Flutter -> RN)

### 1.1 Core
| Flutter | RN target | Status |
|---|---|---|
| `core/config/contact.dart` | `src/core/config/contact.ts` | missing |
| `core/config/env.dart` | `src/core/config/env.ts` | done (basic) |
| `core/diagnostics/diagnostics_uploader.dart` | `src/core/diagnostics/diagnosticsUploader.ts` | missing |
| `core/errors/failures.dart` | `src/core/errors/failures.ts` | done (basic) |
| `core/geo/geo.dart` | `src/core/geo/geo.ts` | done (basic) |
| `core/geo/route_proximity.dart` | `src/core/geo/routeProximity.ts` | missing |
| `core/logging/log.dart` | `src/core/logging/log.ts` | done (basic) |
| `core/net/backoff.dart` | `src/core/net/backoff.ts` | done (basic) |
| `core/time/clock.dart` | `src/core/time/clock.ts` | done (basic) |

### 1.2 Data
| Flutter | RN target | Status |
|---|---|---|
| `data/api/bus_api.dart` | `src/data/api/busApi.ts` | partial |
| `data/api/dto.dart` | `src/data/api/dto.ts` | partial |
| `data/config/remote_config.dart` | `src/data/config/remoteConfig.ts` | partial |
| `data/learning/learning_repository.dart` | `src/data/learning/learningRepository.ts` | partial |
| `data/net/http_client.dart` + io/stub | `src/data/net/httpClient.ts` (+ `.native.ts`, `.web.ts`) | missing |
| `data/prefs/consent_store.dart` | `src/data/prefs/consentStore.ts` | partial |
| `data/prefs/report_location_notice.dart` | `src/data/prefs/reportLocationNotice.ts` | missing |
| `data/prefs/theme_store.dart` | `src/data/prefs/themeStore.ts` | partial |
| `data/prefs/token_store.dart` | `src/data/prefs/tokenStore.ts` | partial |
| `data/realtime/vehicle_repository.dart` | `src/data/realtime/vehicleRepository.ts` | partial |
| `data/static_data/static_data.dart` | `src/data/static/staticData.ts` | partial |

### 1.3 Domain
| Flutter | RN target | Status |
|---|---|---|
| `domain/learning/eta_estimate.dart` | `src/domain/learning/etaEstimate.ts` | missing |
| `domain/learning/learned_route.dart` | `src/domain/learning/learnedRoute.ts` | missing |
| `domain/learning/learned_route_index.dart` | `src/domain/learning/learnedRouteIndex.ts` | missing |
| `domain/learning/learned_stop.dart` | `src/domain/learning/learnedStop.ts` | missing |
| `domain/learning/place.dart` | `src/domain/learning/place.ts` | missing |
| `domain/line_category.dart` | `src/domain/lineCategory.ts` | missing |
| `domain/reporting/report_area.dart` | `src/domain/reporting/reportArea.ts` | missing (logic in report.ts) |
| `domain/reporting/report_kind.dart` | `src/domain/reporting/reportKind.ts` | missing (logic in report.ts) |
| `domain/schedule.dart` | `src/domain/schedule.ts` | missing |
| `domain/trip/auto_end.dart` | `src/domain/trip/autoEnd.ts` | partial |
| `domain/trip/sampling_policy.dart` | `src/domain/trip/samplingPolicy.ts` | missing |
| `domain/trip/share_phases.dart` | `src/domain/trip/sharePhases.ts` | missing |
| `domain/trip/sharing_health.dart` | `src/domain/trip/sharingHealth.ts` | missing |
| `domain/trip/trip_state.dart` | `src/domain/trip/tripState.ts` | partial |

### 1.4 Features
| Flutter | RN target | Status |
|---|---|---|
| `features/map/offline_map.dart` | `src/features/map/offlineMap.ts` | missing |
| `features/map/tile_source.dart` | `src/features/map/tileSource.ts` | missing |
| `features/reports/report_location.dart` | `src/features/reports/reportLocation.ts` | missing |
| `features/settings/privacy_actions.dart` | `src/features/settings/privacyActions.ts` | missing |
| `features/settings/privacy_texts.dart` | `src/features/settings/privacyTexts.ts` | missing |
| `features/trip/consent_flow.dart` | `src/features/trip/consentFlow.ts` | missing |
| `features/trip/consent_sheet.dart` | `src/features/trip/consentSheet.tsx` | missing |
| `features/trip/location_service.dart` | `src/features/trip/locationService.ts` | missing |
| `features/trip/permission_sheet.dart` | `src/features/trip/permissionSheet.tsx` | missing |
| `features/trip/ping_client.dart` | `src/features/trip/pingClient.ts` | missing |
| `features/trip/share_flow.dart` | `src/features/trip/shareFlow.ts` | missing |
| `features/trip/share_progress_sheet.dart` | `src/features/trip/shareProgressSheet.tsx` | missing |
| `features/trip/share_progress_tracker.dart` | `src/features/trip/shareProgressTracker.ts` | missing |
| `features/trip/trip_controller.dart` | `src/features/trip/tripController.ts` | missing |
| `features/trip/trip_supervisor.dart` | `src/features/trip/tripSupervisor.ts` | missing |

### 1.5 Platform
| Flutter | RN target | Status |
|---|---|---|
| `platform/android/battery_optimization.dart` | `src/platform/android/batteryOptimization.ts` | missing |
| `platform/android/gnss_quality.dart` | `src/platform/android/gnssQuality.ts` | missing |
| `platform/android/notification_permission.dart` | `src/platform/android/notificationPermission.ts` | missing |
| `platform/android/permission_gateway.dart` | `src/features/trip/permissionGateway.ts` (exists) + `src/platform/android/permissionGateway.ts` | partial |
| `platform/web/android_app_download.dart` | `src/platform/web/androidAppDownload.tsx` | missing |
| `platform/web/install_hint.dart` | `src/platform/web/installHint.tsx` | missing |
| `platform/web/user_agent.dart` (+ stub/web) | `src/platform/web/userAgent.ts` (+ `.web.ts`) | missing |
| `platform/web/visibility.dart` | `src/platform/web/visibility.ts` | missing |
| `platform/web/wake_lock.dart` | `src/platform/web/wakeLock.ts` | missing |
| `platform/web/web_banner.dart` | `src/platform/web/webBanner.tsx` | missing |

### 1.6 UI components (all 36 + 4 icons must be ported)
Components:
`alert_sheet`, `arrival_row`, `banner`, `buttons`, `certainty_badge`, `certainty_style`, `chip`, `confidence_meter`, `dashed_outline`, `empty_state`, `eta_text`, `ghost_link`, `ghost_marker`, `icon_btn`, `line_badge`, `line_row`, `live_dot`, `live_pulse`, `permission_card`, `pontual_sheet`, `predicted_path`, `prediction_info_sheet`, `pressable`, `reliability_card`, `search_field`, `section_header`, `segmented`, `shortcut_card`, `skeleton`, `sparkline`, `surface_card`, `time_rail`, `toast`, `trip_dock`, `vehicle_marker`, `vehicle_row`.

Icons:
`bus_icon`, `live_waves_icon`, `route_icon`, `spark_icon`.

Tokens:
`colors`, `line_colors`, `motion`, `spacing`, `text`.

Theme:
`context`, `theme`, `theme_bridge`.

### 1.7 UI features and screens
Home: `first_run`, `home_lists`, `home_logic`, `home_providers`, `home_screen`, `home_sections`, `shortcut_sheet`, `welcome_state`.

Line: `line_dock`, `line_expanded`, `line_map`, `line_map_controls`, `line_not_found`, `line_screen`, `line_sheet`, `line_sheet_geometry`, `line_sheet_header`, `viewer_location`.

Lines: `favorites_store_bridge`, `lines_logic`, `lines_screen`.

Reports: `report_actions`, `report_chip`, `report_detail_sheet`, `report_location_notice`, `report_sheet`, `reports_providers`, `report_strip`, `report_style`.

Search: `place_search`, `search_screen`.

Settings: `about_screen`, `android_app_download_row`, `privacy_screen`, `settings_row`, `settings_screen`, `settings_section`.

System: `system_screen`.

Timetable: `timetable_data`, `timetable_tab`.

Trip: `line_chooser_sheet`, `permission_sheets`, `trip_end_card`, `trip_flow`, `trip_hero`, `trip_metrics`, `trip_screen`, `trip_status`.

Models: `alert_rule`, `arrival_vm`, `certainty`, `features`, `line_status`, `line_vm`, `reliability`, `report_vm`, `shortcut_vm`, `trip_vm`, `vehicle_vm`.

Adapters: `alerts_store`, `arrivals_adapter`, `lines_adapter`, `local_stores`, `now_clock`, `reports_adapter`, `trip_adapter`, `vehicles_adapter`.

Shell: `app_shell`, `bottom_nav`, `dock_host`, `offline_bridge`, `scroll_behavior`, `toast_host`, `trip_host`.

Util: `contrast`, `format_eta`, `frame_timing`, `lifecycle_ticks`, `platform`, `search_index`.

Router: `app_router`, `page_transition`, `route_observer`.

Strings: `ui_strings`.

### 1.8 Tests
Flutter tests live under `app/test/` and `app/integration_test/`. RN must add equivalent unit/integration tests. Server tests remain Deno and are not part of RN recreation except client calls.

## 2. RN architecture decisions

- Routing: Expo Router file-based routes in `src/app/`.
- State: zustand stores; keep providers thin. Domain logic in pure TS modules.
- Data: fetch + zod validation; AsyncStorage for prefs; SecureStore for token (preferred over AsyncStorage for token).
- Map: MapLibre (`@maplibre/maplibre-react-native` native, `maplibre-gl` web) behind a `Map` component. Keep TileSource abstraction.
- Location: `expo-location` for permissions/fixes; Android foreground service requires a native module or an Expo config plugin. Spike required.
- Styling: design tokens in TS; prefer `StyleSheet`; theme via React context; support system/light/dark.
- Accessibility: RN `accessibilityLabel`, `accessibilityRole`, `accessibilityLiveRegion`.
- Platform branching: `.native.ts`/`.web.ts` or `Platform.OS`.

## 3. Phase plan

### Phase 0 - Audit and scaffolding hardening
Tasks:
- P0.1 Freeze current scaffold; run `npx tsc --noEmit`, `npx expo lint`, `npx expo export --platform web`. Record baseline.
- P0.2 Add lint/format config (eslint already; add prettier optional via ADR). Do not add deps without ADR.
- P0.3 Add test runner (Jest via Expo) and a smoke test. Verify `npm test` works.
- P0.4 Create folder structure for all parity modules (empty barrels) to avoid churn.
Acceptance: typecheck/lint/export/test pass.

### Phase 1 - Core and data parity
- P1.1 Implement `contact.ts`, `diagnosticsUploader.ts`, `routeProximity.ts`.
- P1.2 Upgrade `busApi.ts` to full parity: ETag vehicles, live, arrivals, trip start/ping/end, reports, consents, devices, deleteMe, learned routes/stops/eta, allLearnedRoutes, health. Strict zod parsing. Timeout 8-15s.
- P1.3 Complete DTOs with all server payloads and strict schemas.
- P1.4 Implement HTTP client module with keep-alive where possible (fetch keepalive), timeout, retry classification hooks.
- P1.5 Complete consent store, token store (SecureStore), theme store, report location notice store, storage helpers.
- P1.6 Complete static data repository: bundled asset, cached remote, conditional manifest <=1/day, atomic swap, schema validation, fallback.
- P1.7 Complete remote config: maintenance, min app version, consent version, tile URL, caching.
- P1.8 Complete vehicle repository: WebSocket sub/unsub, snapshot, watchdog 45s, polling fallback 20s, reconnect backoff with jitter, bye restart, pause/resume handling, ETag snapshot.
- P1.9 Complete learning repository and domain models (eta estimate, learned route/stop/index, place).
Acceptance: unit tests for parsing, backoff, static data, vehicle repository state machine.

### Phase 2 - Domain and trip engine parity
- P2.1 Implement trip state sealed union (discriminated union) and share phases.
- P2.2 Implement sampling policy pure function (modes, hysteresis, degraded hold).
- P2.3 Implement auto-end rules (idle, max duration, permission lost, server end).
- P2.4 Implement sharing health model.
- P2.5 Implement report domain (kind, area hashing, report VM formatting rules).
- P2.6 Implement schedule model and timetable data helpers.
- P2.7 Implement line category and certainty/reliability models.
- P2.8 Implement place search model/index.
Acceptance: unit tests for all pure functions, including edge cases.

### Phase 3 - Design system
- P3.1 Tokens: colors, line colors (deterministic 6-color palette), motion, spacing, text.
- P3.2 Theme context/provider with system/light/dark; dark near-black surfaces.
- P3.3 Port all 36 components and 4 icons to RN with accessibility labels, 48dp targets, reduce-motion support.
- P3.4 Port adapters and view models.
- P3.5 Port shell: app shell, bottom nav, dock host, offline bridge, scroll behavior, toast host, trip host.
- P3.6 Port strings to `ui_strings.ts` constants (pt-BR).
Acceptance: component snapshot/render tests; no clipped text at 200% scale on 360dp.

### Phase 4 - Navigation and shell
- P4.1 Expo Router routes for all paths: `/welcome`, `/`, `/line/[id]`, `/trip`, `/settings`, `/privacy`, `/privacy/policy`, `/privacy/terms`, `/about`, `/system`, plus search.
- P4.2 Tab/stack layout matching navigation map; trip route cannot be popped without confirmation while active.
- P4.3 Global overlays: offline banner, maintenance, update required.
- P4.4 Page transitions and route observer.
Acceptance: deep links open correct screens; back behavior matches spec.

### Phase 5 - Screens (S01-S15)
Implement each screen per PLAN 9.5:
- P5.1 S01 native splash (app.json splash + expo-splash-screen).
- P5.2 S02 Welcome (first run).
- P5.3 S03 Home/Linhas full parity (live indicators, search, pull-to-refresh min 10s, no polling timer, empty/offline states).
- P5.4 S04 Line Mapa tab (map, markers, status row, text alternative list, share button gating for pilot, leaving closes stream).
- P5.5 S05 Line Horarios tab (day type default today Sao Mateus, origin selector, next departure highlight, chips grouped by hour, past dimmed, disclaimer, empty state, no network).
- P5.6 S06 Share-trip consent sheet (prominent disclosure, versioned text, lone-rider disclosure, accept/register/consent/permission/start).
- P5.7 S07 Permission education and denied states (foreground location, notification, services off, web instructions).
- P5.8 S08 Trip active (status liveRegion, elapsed ticker only visible, connection, GPS, role, help card battery, Desci, web banner/wake lock, RF16 prompt).
- P5.9 S09 Trip ended (reason, back to lines).
- P5.10 S10 Settings (theme, privacy, about, help, contact, version/data version).
- P5.11 S11 Privacy center (policy/terms offline, collection summary, delete data, revoke consent, offline honest error).
- P5.12 S12 About and data sources (independent disclaimer, sources, OSM attribution, licenses, repo link).
- P5.13 S13 System screens (maintenance, update required, server unavailable).
- P5.14 S14 Offline banner global.
- P5.15 S15 Reports full UI (entry points, sheet 4 options, location card coarse cell, notice, denied/blocked/imprecise/timeout cards, report rows wording, detail sheet distance, retract own report, expiry handling, kill switch).
Acceptance: each screen matches UI spec states and microcopy; manual checklist.

### Phase 6 - Map, static data, and place search
- P6.1 Map component parity: TileSource abstraction (OSM default), attribution, cache cap, zoom 12-17, bbox constraint, retina off, pan/pinch only, RepaintBoundary equivalent, marker tween <=800ms unless reduce motion, max ~20 markers, dark UI dim only.
- P6.2 Offline map helpers.
- P6.3 Place search screen and search index.
Acceptance: map perf on mid device; no tile prefetch.

### Phase 7 - Trip sharing runtime
- P7.1 Consent flow (version check, register, post consent, offline store+retry).
- P7.2 Location service (fix production, drop rules: mocked, accuracy>60, bbox, stale>20s; rounding; seq per accepted fix; anchors).
- P7.3 Sampling policy integration with role changes and hysteresis.
- P7.4 Ping client full failure classification and backoff.
- P7.5 Trip controller (single owner, FGS start/stop, notifications, effects).
- P7.6 Trip supervisor (permission loss, GPS off, mock detection, approximate downgrade, paused).
- P7.7 Auto-end integration and trip ended reasons.
- P7.8 Share progress tracker and sheet.
- P7.9 Trip metrics (elapsed, connection, GPS, role, satellites if available).
- P7.10 Line chooser sheet for trip start.
Acceptance: two-device field test; server sees pings; auto-end works.

### Phase 8 - Reports runtime
- P8.1 Report location notice (first-use).
- P8.2 Coarse cell conversion on-device; exact coords never sent.
- P8.3 Permission states and retry.
- P8.4 Create/retract via API; 429 handling; expiry handling.
- P8.5 Report strip/chips/overflow and detail sheet.
Acceptance: reports appear in vehicle snapshot; expiry closes sheet.

### Phase 9 - Learning/ETA runtime
- P9.1 Learned route index and ETA estimate pure functions.
- P9.2 ETA UI (arrival rows, certainty badge, confidence meter, predicted path, prediction info sheet).
- P9.3 Sparkline/time rail if used.
Acceptance: ETA displays when learned data exists; no crash on missing.

### Phase 10 - Platform and native
- P10.1 Android: permissions list exact; FGS location service; notification channel; swipe-away ends trip; battery optimization card; GNSS quality channel (if native module available).
- P10.2 Web: wake lock, visibility handling, install hint, android app download row, user agent detection, web banner.
- P10.3 Consent revocation half-life client side.
Acceptance: merged Android manifest audit passes; web trip banner visible.

### Phase 11 - Privacy, security, and legal
- P11.1 Secure token storage (SecureStore), allowBackup false equivalent (Android config).
- P11.2 Delete my data flow and honest offline error.
- P11.3 Revoke consent flow.
- P11.4 Policy/terms bundled offline + canonical link.
- P11.5 Diagnostics opt-out and 14-day retention (if adopted).
- P11.6 Secret scan and no coordinate logging.
Acceptance: security checklist AC01-AC23 client-side applicable; gitleaks clean.

### Phase 12 - Performance, battery, data
- P12.1 Budgets measurement on reference devices.
- P12.2 Bundle size check (web first load, Android AAB).
- P12.3 Marker cap and graceful degradation.
- P12.4 No polling timers where spec says none (home live indicators).
- P12.5 Image/font minimal (system font only).
Acceptance: budgets recorded in DECISIONS.md or stated not measured.

### Phase 13 - Testing and QA
- P13.1 Unit tests: domain, dto parsing, backoff, sampling, report area, static data.
- P13.2 Component tests: key components render.
- P13.3 Integration: trip flow with mocked server.
- P13.4 Security tests: no token leaks, no coords in logs, 401 handling.
- P13.5 Accessibility tests: 200% scale, reduce motion.
- P13.6 Field test protocol (docs/field-tests).
Acceptance: test suite green in CI.

### Phase 14 - CI/CD and release
- P14.1 GitHub Actions: typecheck, lint, tests, data validation, gitleaks, manifest audit, size report.
- P14.2 EAS build profiles (dev, preview, prod) and submit config.
- P14.3 Release checklist and versioning.
- P14.4 Web deploy to Pages/Cloudflare; env vars.
Acceptance: CI green on PR; EAS build succeeds.

### Phase 15 - Cutover and verification
- P15.1 Full parity checklist review (this plan section 4).
- P15.2 Device field tests (two phones, one bus).
- P15.3 Owner sign-off.
- P15.4 Rename app from "Pontual (RN)" to "Pontual" and set applicationId/package.
Acceptance: alpha exit criteria (PLAN 1.6) met for RN client.

## 4. Screen acceptance details (condensed)

Each screen must implement all states from PLAN 9.5:
- Loading from cache first, no full-screen spinner on cached content.
- Empty states exact microcopy.
- Offline banner non-blocking.
- 200% text scale no clip.
- Accessibility labels pt-BR.
- Reduce motion respected.

## 5. Native Android specifics (must audit)
Permissions (exact set):
`INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
Forbidden: `ACCESS_BACKGROUND_LOCATION`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` unless spike proves indispensable.
- FGS type location; start only after user tap.
- Notification channel "Viagem ativa"; ongoing; low importance.
- Swipe from recents ends trip.
- Battery exemption dialog only from user tap on offline card.

## 6. Web/PWA specifics
- Foreground-only sharing; wake lock; banner "Mantenha esta tela aberta...".
- Visibility handling: pause/stop after >60s hidden; revive on visible.
- iOS install hint.
- Service worker caches app shell + lines hash only; never API/tiles.
- Security headers via `_headers`.

## 7. Risks
- RN foreground service location parity with Flutter may require native module; spike early.
- Expo Location background updates are not allowed by policy; keep foreground-only.
- MapLibre RN performance and tile cache configuration differ from flutter_map; measure.
- Bundle size may exceed budgets; optimize early.
- Learning/ETA parity depends on server endpoints; verify contracts.

## 8. Definition of done for RN recreation
- All screens S01-S15 implemented and verified.
- All components and tokens ported.
- All domain/data modules ported and tested.
- Trip sharing works on Android and web foreground.
- Reports work end-to-end.
- Security/privacy checks pass.
- CI green; EAS build succeeds.
- Budgets measured or explicitly stated not measured.
- Owner sign-off.


## Appendix A - Complete Flutter file inventory and RN mapping

| Flutter source (lib/) | RN target (rn/src/) | Status |
|---|---|---|
| `app/providers.dart` | `src/TBD` | pending |
| `core/config/contact.dart` | `src/core/config/contact.ts` | pending |
| `core/config/env.dart` | `src/core/config/env.ts` | pending |
| `core/diagnostics/diagnostics_uploader.dart` | `src/core/diagnostics/diagnostics_uploader.ts` | pending |
| `core/errors/failures.dart` | `src/core/errors/failures.ts` | pending |
| `core/geo/geo.dart` | `src/core/geo/geo.ts` | pending |
| `core/geo/route_proximity.dart` | `src/core/geo/route_proximity.ts` | pending |
| `core/logging/log.dart` | `src/core/logging/log.ts` | pending |
| `core/net/backoff.dart` | `src/core/net/backoff.ts` | pending |
| `core/time/clock.dart` | `src/core/time/clock.ts` | pending |
| `data/api/bus_api.dart` | `src/data/api/bus_api.ts` | pending |
| `data/api/dto.dart` | `src/data/api/dto.ts` | pending |
| `data/config/remote_config.dart` | `src/data/config/remote_config.ts` | pending |
| `data/learning/learning_repository.dart` | `src/data/learning/learning_repository.ts` | pending |
| `data/net/http_client.dart` | `src/data/net/http_client.ts` | pending |
| `data/net/http_client_io.dart` | `src/data/net/http_client_io.ts` | pending |
| `data/net/http_client_stub.dart` | `src/data/net/http_client_stub.ts` | pending |
| `data/prefs/consent_store.dart` | `src/data/prefs/consent_store.ts` | pending |
| `data/prefs/report_location_notice.dart` | `src/data/prefs/report_location_notice.ts` | pending |
| `data/prefs/theme_store.dart` | `src/data/prefs/theme_store.ts` | pending |
| `data/prefs/token_store.dart` | `src/data/prefs/token_store.ts` | pending |
| `data/realtime/vehicle_repository.dart` | `src/data/realtime/vehicle_repository.ts` | pending |
| `data/static_data/static_data.dart` | `src/data/static_data/static_data.ts` | pending |
| `domain/learning/eta_estimate.dart` | `src/domain/learning/eta_estimate.ts` | pending |
| `domain/learning/learned_route.dart` | `src/domain/learning/learned_route.ts` | pending |
| `domain/learning/learned_route_index.dart` | `src/domain/learning/learned_route_index.ts` | pending |
| `domain/learning/learned_stop.dart` | `src/domain/learning/learned_stop.ts` | pending |
| `domain/learning/place.dart` | `src/domain/learning/place.ts` | pending |
| `domain/line_category.dart` | `src/domain/line_category.ts` | pending |
| `domain/reporting/report_area.dart` | `src/domain/reporting/report_area.ts` | pending |
| `domain/reporting/report_kind.dart` | `src/domain/reporting/report_kind.ts` | pending |
| `domain/schedule.dart` | `src/domain/schedule.ts` | pending |
| `domain/trip/auto_end.dart` | `src/domain/trip/auto_end.ts` | pending |
| `domain/trip/sampling_policy.dart` | `src/domain/trip/sampling_policy.ts` | pending |
| `domain/trip/share_phases.dart` | `src/domain/trip/share_phases.ts` | pending |
| `domain/trip/sharing_health.dart` | `src/domain/trip/sharing_health.ts` | pending |
| `domain/trip/trip_state.dart` | `src/domain/trip/trip_state.ts` | pending |
| `features/map/offline_map.dart` | `src/features/map/offline_map.ts` | pending |
| `features/map/tile_source.dart` | `src/features/map/tile_source.ts` | pending |
| `features/reports/report_location.dart` | `src/features/reports/report_location.ts` | pending |
| `features/settings/privacy_actions.dart` | `src/features/settings/privacy_actions.ts` | pending |
| `features/settings/privacy_texts.dart` | `src/features/settings/privacy_texts.ts` | pending |
| `features/trip/consent_flow.dart` | `src/features/trip/consent_flow.ts` | pending |
| `features/trip/consent_sheet.dart` | `src/features/trip/consent_sheet.ts` | pending |
| `features/trip/location_service.dart` | `src/features/trip/location_service.ts` | pending |
| `features/trip/permission_sheet.dart` | `src/features/trip/permission_sheet.ts` | pending |
| `features/trip/ping_client.dart` | `src/features/trip/ping_client.ts` | pending |
| `features/trip/share_flow.dart` | `src/features/trip/share_flow.ts` | pending |
| `features/trip/share_progress_sheet.dart` | `src/features/trip/share_progress_sheet.ts` | pending |
| `features/trip/share_progress_tracker.dart` | `src/features/trip/share_progress_tracker.ts` | pending |
| `features/trip/trip_controller.dart` | `src/features/trip/trip_controller.ts` | pending |
| `features/trip/trip_supervisor.dart` | `src/features/trip/trip_supervisor.ts` | pending |
| `main.dart` | `src/(Expo entry, no direct file)` | pending |
| `platform/android/battery_optimization.dart` | `src/platform/android/battery_optimization.ts` | pending |
| `platform/android/gnss_quality.dart` | `src/platform/android/gnss_quality.ts` | pending |
| `platform/android/notification_permission.dart` | `src/platform/android/notification_permission.ts` | pending |
| `platform/android/permission_gateway.dart` | `src/platform/android/permission_gateway.ts` | pending |
| `platform/web/android_app_download.dart` | `src/platform/web/android_app_download.ts` | pending |
| `platform/web/install_hint.dart` | `src/platform/web/install_hint.ts` | pending |
| `platform/web/user_agent.dart` | `src/platform/web/user_agent.ts` | pending |
| `platform/web/user_agent_stub.dart` | `src/platform/web/user_agent_stub.ts` | pending |
| `platform/web/user_agent_web.dart` | `src/platform/web/user_agent_web.ts` | pending |
| `platform/web/visibility.dart` | `src/platform/web/visibility.ts` | pending |
| `platform/web/wake_lock.dart` | `src/platform/web/wake_lock.ts` | pending |
| `platform/web/web_banner.dart` | `src/platform/web/web_banner.ts` | pending |
| `ui/adapters/alerts_store.dart` | `src/ui/adapters/alerts_store.ts` | pending |
| `ui/adapters/arrivals_adapter.dart` | `src/ui/adapters/arrivals_adapter.ts` | pending |
| `ui/adapters/lines_adapter.dart` | `src/ui/adapters/lines_adapter.ts` | pending |
| `ui/adapters/local_stores.dart` | `src/ui/adapters/local_stores.ts` | pending |
| `ui/adapters/now_clock.dart` | `src/ui/adapters/now_clock.ts` | pending |
| `ui/adapters/reports_adapter.dart` | `src/ui/adapters/reports_adapter.ts` | pending |
| `ui/adapters/trip_adapter.dart` | `src/ui/adapters/trip_adapter.ts` | pending |
| `ui/adapters/vehicles_adapter.dart` | `src/ui/adapters/vehicles_adapter.ts` | pending |
| `ui/design/adapters/theme_bridge.dart` | `src/ui/design/adapters/theme_bridge.ts` | pending |
| `ui/design/components/alert_sheet.dart` | `src/ui/design/components/alert_sheet.tsx` | pending |
| `ui/design/components/arrival_row.dart` | `src/ui/design/components/arrival_row.tsx` | pending |
| `ui/design/components/banner.dart` | `src/ui/design/components/banner.tsx` | pending |
| `ui/design/components/buttons.dart` | `src/ui/design/components/buttons.tsx` | pending |
| `ui/design/components/certainty_badge.dart` | `src/ui/design/components/certainty_badge.tsx` | pending |
| `ui/design/components/certainty_style.dart` | `src/ui/design/components/certainty_style.tsx` | pending |
| `ui/design/components/chip.dart` | `src/ui/design/components/chip.tsx` | pending |
| `ui/design/components/confidence_meter.dart` | `src/ui/design/components/confidence_meter.tsx` | pending |
| `ui/design/components/dashed_outline.dart` | `src/ui/design/components/dashed_outline.tsx` | pending |
| `ui/design/components/empty_state.dart` | `src/ui/design/components/empty_state.tsx` | pending |
| `ui/design/components/eta_text.dart` | `src/ui/design/components/eta_text.tsx` | pending |
| `ui/design/components/ghost_link.dart` | `src/ui/design/components/ghost_link.tsx` | pending |
| `ui/design/components/ghost_marker.dart` | `src/ui/design/components/ghost_marker.tsx` | pending |
| `ui/design/components/icon_btn.dart` | `src/ui/design/components/icon_btn.tsx` | pending |
| `ui/design/components/line_badge.dart` | `src/ui/design/components/line_badge.tsx` | pending |
| `ui/design/components/line_row.dart` | `src/ui/design/components/line_row.tsx` | pending |
| `ui/design/components/live_dot.dart` | `src/ui/design/components/live_dot.tsx` | pending |
| `ui/design/components/live_pulse.dart` | `src/ui/design/components/live_pulse.tsx` | pending |
| `ui/design/components/permission_card.dart` | `src/ui/design/components/permission_card.tsx` | pending |
| `ui/design/components/pontual_sheet.dart` | `src/ui/design/components/pontual_sheet.tsx` | pending |
| `ui/design/components/predicted_path.dart` | `src/ui/design/components/predicted_path.tsx` | pending |
| `ui/design/components/prediction_info_sheet.dart` | `src/ui/design/components/prediction_info_sheet.tsx` | pending |
| `ui/design/components/pressable.dart` | `src/ui/design/components/pressable.tsx` | pending |
| `ui/design/components/reliability_card.dart` | `src/ui/design/components/reliability_card.tsx` | pending |
| `ui/design/components/search_field.dart` | `src/ui/design/components/search_field.tsx` | pending |
| `ui/design/components/section_header.dart` | `src/ui/design/components/section_header.tsx` | pending |
| `ui/design/components/segmented.dart` | `src/ui/design/components/segmented.tsx` | pending |
| `ui/design/components/shortcut_card.dart` | `src/ui/design/components/shortcut_card.tsx` | pending |
| `ui/design/components/skeleton.dart` | `src/ui/design/components/skeleton.tsx` | pending |
| `ui/design/components/sparkline.dart` | `src/ui/design/components/sparkline.tsx` | pending |
| `ui/design/components/surface_card.dart` | `src/ui/design/components/surface_card.tsx` | pending |
| `ui/design/components/time_rail.dart` | `src/ui/design/components/time_rail.tsx` | pending |
| `ui/design/components/toast.dart` | `src/ui/design/components/toast.tsx` | pending |
| `ui/design/components/trip_dock.dart` | `src/ui/design/components/trip_dock.tsx` | pending |
| `ui/design/components/vehicle_marker.dart` | `src/ui/design/components/vehicle_marker.tsx` | pending |
| `ui/design/components/vehicle_row.dart` | `src/ui/design/components/vehicle_row.tsx` | pending |
| `ui/design/gallery/gallery_screen.dart` | `src/ui/design/gallery/gallery_screen.ts` | pending |
| `ui/design/icons/bus_icon.dart` | `src/ui/design/icons/bus_icon.ts` | pending |
| `ui/design/icons/live_waves_icon.dart` | `src/ui/design/icons/live_waves_icon.ts` | pending |
| `ui/design/icons/route_icon.dart` | `src/ui/design/icons/route_icon.ts` | pending |
| `ui/design/icons/spark_icon.dart` | `src/ui/design/icons/spark_icon.ts` | pending |
| `ui/design/theme/context.dart` | `src/ui/design/theme/context.ts` | pending |
| `ui/design/theme/theme.dart` | `src/ui/design/theme/theme.ts` | pending |
| `ui/design/tokens/colors.dart` | `src/ui/design/tokens/colors.ts` | pending |
| `ui/design/tokens/line_colors.dart` | `src/ui/design/tokens/line_colors.ts` | pending |
| `ui/design/tokens/motion.dart` | `src/ui/design/tokens/motion.ts` | pending |
| `ui/design/tokens/spacing.dart` | `src/ui/design/tokens/spacing.ts` | pending |
| `ui/design/tokens/text.dart` | `src/ui/design/tokens/text.ts` | pending |
| `ui/features/home/first_run.dart` | `src/ui/features/home/first_run.tsx` | pending |
| `ui/features/home/home_lists.dart` | `src/ui/features/home/home_lists.tsx` | pending |
| `ui/features/home/home_logic.dart` | `src/ui/features/home/home_logic.tsx` | pending |
| `ui/features/home/home_providers.dart` | `src/ui/features/home/home_providers.tsx` | pending |
| `ui/features/home/home_screen.dart` | `src/ui/features/home/home_screen.tsx` | pending |
| `ui/features/home/home_sections.dart` | `src/ui/features/home/home_sections.tsx` | pending |
| `ui/features/home/shortcut_sheet.dart` | `src/ui/features/home/shortcut_sheet.tsx` | pending |
| `ui/features/home/welcome_state.dart` | `src/ui/features/home/welcome_state.tsx` | pending |
| `ui/features/line/line_dock.dart` | `src/ui/features/line/line_dock.tsx` | pending |
| `ui/features/line/line_expanded.dart` | `src/ui/features/line/line_expanded.tsx` | pending |
| `ui/features/line/line_map.dart` | `src/ui/features/line/line_map.tsx` | pending |
| `ui/features/line/line_map_controls.dart` | `src/ui/features/line/line_map_controls.tsx` | pending |
| `ui/features/line/line_not_found.dart` | `src/ui/features/line/line_not_found.tsx` | pending |
| `ui/features/line/line_screen.dart` | `src/ui/features/line/line_screen.tsx` | pending |
| `ui/features/line/line_sheet.dart` | `src/ui/features/line/line_sheet.tsx` | pending |
| `ui/features/line/line_sheet_geometry.dart` | `src/ui/features/line/line_sheet_geometry.tsx` | pending |
| `ui/features/line/line_sheet_header.dart` | `src/ui/features/line/line_sheet_header.tsx` | pending |
| `ui/features/line/viewer_location.dart` | `src/ui/features/line/viewer_location.tsx` | pending |
| `ui/features/lines/favorites_store_bridge.dart` | `src/ui/features/lines/favorites_store_bridge.tsx` | pending |
| `ui/features/lines/lines_logic.dart` | `src/ui/features/lines/lines_logic.tsx` | pending |
| `ui/features/lines/lines_screen.dart` | `src/ui/features/lines/lines_screen.tsx` | pending |
| `ui/features/reports/report_actions.dart` | `src/ui/features/reports/report_actions.tsx` | pending |
| `ui/features/reports/report_chip.dart` | `src/ui/features/reports/report_chip.tsx` | pending |
| `ui/features/reports/report_detail_sheet.dart` | `src/ui/features/reports/report_detail_sheet.tsx` | pending |
| `ui/features/reports/report_location_notice.dart` | `src/ui/features/reports/report_location_notice.tsx` | pending |
| `ui/features/reports/report_sheet.dart` | `src/ui/features/reports/report_sheet.tsx` | pending |
| `ui/features/reports/report_strip.dart` | `src/ui/features/reports/report_strip.tsx` | pending |
| `ui/features/reports/report_style.dart` | `src/ui/features/reports/report_style.tsx` | pending |
| `ui/features/reports/reports_providers.dart` | `src/ui/features/reports/reports_providers.tsx` | pending |
| `ui/features/search/place_search.dart` | `src/ui/features/search/place_search.tsx` | pending |
| `ui/features/search/search_screen.dart` | `src/ui/features/search/search_screen.tsx` | pending |
| `ui/features/settings/about_screen.dart` | `src/ui/features/settings/about_screen.tsx` | pending |
| `ui/features/settings/android_app_download_row.dart` | `src/ui/features/settings/android_app_download_row.tsx` | pending |
| `ui/features/settings/privacy_screen.dart` | `src/ui/features/settings/privacy_screen.tsx` | pending |
| `ui/features/settings/settings_row.dart` | `src/ui/features/settings/settings_row.tsx` | pending |
| `ui/features/settings/settings_screen.dart` | `src/ui/features/settings/settings_screen.tsx` | pending |
| `ui/features/settings/settings_section.dart` | `src/ui/features/settings/settings_section.tsx` | pending |
| `ui/features/system/system_screen.dart` | `src/ui/features/system/system_screen.tsx` | pending |
| `ui/features/timetable/timetable_data.dart` | `src/ui/features/timetable/timetable_data.tsx` | pending |
| `ui/features/timetable/timetable_tab.dart` | `src/ui/features/timetable/timetable_tab.tsx` | pending |
| `ui/features/trip/line_chooser_sheet.dart` | `src/ui/features/trip/line_chooser_sheet.tsx` | pending |
| `ui/features/trip/permission_sheets.dart` | `src/ui/features/trip/permission_sheets.tsx` | pending |
| `ui/features/trip/trip_end_card.dart` | `src/ui/features/trip/trip_end_card.tsx` | pending |
| `ui/features/trip/trip_flow.dart` | `src/ui/features/trip/trip_flow.tsx` | pending |
| `ui/features/trip/trip_hero.dart` | `src/ui/features/trip/trip_hero.tsx` | pending |
| `ui/features/trip/trip_metrics.dart` | `src/ui/features/trip/trip_metrics.tsx` | pending |
| `ui/features/trip/trip_screen.dart` | `src/ui/features/trip/trip_screen.tsx` | pending |
| `ui/features/trip/trip_status.dart` | `src/ui/features/trip/trip_status.tsx` | pending |
| `ui/models/alert_rule.dart` | `src/ui/models/alert_rule.ts` | pending |
| `ui/models/arrival_vm.dart` | `src/ui/models/arrival_vm.ts` | pending |
| `ui/models/certainty.dart` | `src/ui/models/certainty.ts` | pending |
| `ui/models/features.dart` | `src/ui/models/features.ts` | pending |
| `ui/models/line_status.dart` | `src/ui/models/line_status.ts` | pending |
| `ui/models/line_vm.dart` | `src/ui/models/line_vm.ts` | pending |
| `ui/models/reliability.dart` | `src/ui/models/reliability.ts` | pending |
| `ui/models/report_vm.dart` | `src/ui/models/report_vm.ts` | pending |
| `ui/models/shortcut_vm.dart` | `src/ui/models/shortcut_vm.ts` | pending |
| `ui/models/trip_vm.dart` | `src/ui/models/trip_vm.ts` | pending |
| `ui/models/vehicle_vm.dart` | `src/ui/models/vehicle_vm.ts` | pending |
| `ui/router/app_router.dart` | `src/ui/router/app_router.tsx` | pending |
| `ui/router/page_transition.dart` | `src/ui/router/page_transition.tsx` | pending |
| `ui/router/route_observer.dart` | `src/ui/router/route_observer.tsx` | pending |
| `ui/shell/app_shell.dart` | `src/ui/shell/app_shell.tsx` | pending |
| `ui/shell/bottom_nav.dart` | `src/ui/shell/bottom_nav.tsx` | pending |
| `ui/shell/dock_host.dart` | `src/ui/shell/dock_host.tsx` | pending |
| `ui/shell/offline_bridge.dart` | `src/ui/shell/offline_bridge.tsx` | pending |
| `ui/shell/scroll_behavior.dart` | `src/ui/shell/scroll_behavior.tsx` | pending |
| `ui/shell/toast_host.dart` | `src/ui/shell/toast_host.tsx` | pending |
| `ui/shell/trip_host.dart` | `src/ui/shell/trip_host.tsx` | pending |
| `ui/strings/ui_strings.dart` | `src/ui/strings/ui_strings.ts` | pending |
| `ui/util/contrast.dart` | `src/ui/util/contrast.ts` | pending |
| `ui/util/format_eta.dart` | `src/ui/util/format_eta.ts` | pending |
| `ui/util/frame_timing.dart` | `src/ui/util/frame_timing.ts` | pending |
| `ui/util/lifecycle_ticks.dart` | `src/ui/util/lifecycle_ticks.ts` | pending |
| `ui/util/platform.dart` | `src/ui/util/platform.ts` | pending |
| `ui/util/search_index.dart` | `src/ui/util/search_index.ts` | pending |

End of plan.

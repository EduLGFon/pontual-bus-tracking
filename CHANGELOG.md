# Changelog

Format: Keep a Changelog. Versioning: `0.1.0-alpha.N` for alpha builds.

## [Unreleased] - 0.1.0-alpha.0

- Passenger reports ("Sinalizações", D82/D83): waiting, bus full, bus broken
  and access blocked, with a server timestamp and a short TTL. Waiting and
  blocked use a one-shot location read converted on-device to a coarse ~150 m
  area cell; exact coordinates never leave the device. Reads ride on the
  existing line snapshot/WebSocket as an additive `r` array; writes use one
  authenticated `POST /v1/reports` route with `report` and `retract`.
  In-memory only, no free text, no votes, no stop picker. Any viewer can report
  waiting without being on the bus. The first location report shows a one-time
  notice before the OS permission prompt; denied, imprecise and settings states
  are handled in the sheet.
- Settings on the web build now has a permanent "Baixar app para Android"
  row that opens the latest release APK. The one-time card on Home stays;
  the native Android app does not show the row. See DECISIONS.md D81.
- Replaced the launcher, PWA and HTML splash icon with the owner-supplied
  mint bus on a deep green tile. Android legacy and adaptive, web 192/512,
  maskable 192/512, apple-touch 180, SVG and 32 px favicons all use the new
  artwork; see DECISIONS.md D80.
- Copy pass on the pt-BR UI strings: fixed typos and agreement ("Baixe"
  to "Abaixe", "Linha favoritada", "Atualizado" to "Atualizados"),
  made the wake-lock, permission, favorites, and empty-live texts
  clearer and more direct, and pluralized the kudos counter. PLAN.md
  and UI_SPEC.md copy updated to match.
- Trip minimize and system back now return to the screen that started
  sharing (line details, map tab, search) with its state intact, instead
  of replacing the stack with home. The line viewer socket closes while a
  full page covers it and reopens on return; bottom sheets and dialogs do
  not pause it. See DECISIONS.md D77.
- The sharing screen now shows measured metrics instead of short status
  words: GPS accuracy in meters, satellites used and in view, and the
  server send interval with the current role. Meters compare accuracy to
  the 60 m publish gate and satellites used to those in view; missing
  values are named, never invented. See DECISIONS.md D78 and D79.
- D30 momentum anônimo (ordem do dono): ritmo por veículo (um número
  suavizado, sem motorista nem histórico) no snapshot, passagens
  recentes por linha (só instantes, anel de 32, 4 h) com
  `GET /v1/lines/{id}/arrivals`, hero ao vivo na ficha da linha,
  atalhos casa/trabalho/escola ordenados pelo ao vivo, Saindo agora
  com linhas ao vivo primeiro, previsão tracejada e rotulada no mapa,
  cartão de histórico/atraso, alertas locais no app (sem push) e
  contador no aparelho. Recentes e atalhos ficam no aparelho; nada
  novo vai ao servidor além do ritmo e dos instantes em memória.
- UI fix sweep: home links switch to the Linhas tab so the bottom bar
  follows, every screen uses the breakpoint gutter, all sheets share
  the transparent safe-area chrome with keyboard insets where they own
  a field, the trip pill hugs its content and hides under modal sheets
  in both layouts, map controls anchor without overlap, the map frames
  the city on entry and draws a viewer dot from a one-shot lookup
  (already-granted permission only, off in data saver, never sent),
  and lines rows build synchronously for stutter-free scrolling.
- UI_SPEC sections 14-18 compliance: router not-found page, web drag
  scrolling, edge-to-edge transparent bars, tagline on About, exact
  capacity copy, future models and seams (alert rules, reliability
  aggregates, alerts store, live-aware and composite arrivals,
  `localKudos` flag, optional pace factor), flagged future components
  (Sparkline, ConfidenceMeter, AlertSheet, ReliabilityCard,
  PredictionInfoSheet), prediction visuals (GhostMarker, PredictedPath,
  gallery demo), the Saindo agora home feed, a debug frame-timing logger,
  and automated guideline tests in both themes (Segmented raised to 56 dp
  for 48 dp targets; light scheduled and warning text darkened one step
  for badge contrast). Deferred map import stays eager per DECISIONS.md
  D-U20. Brand vector source plus `docs/ui/PERF.md` baseline added; past
  arrivals dim by colour alpha instead of Opacity.
- New UI foundation (docs/ui/UI_SPEC.md): design tokens with WCAG AA
  contrast enforced by a test, Manrope variable subset at 51 KB, custom
  painted domain icons, certainty system (live, predicted, scheduled,
  stale) with a single style table, and 29 design-system components.
- UI architecture: view-models, data seams (ArrivalsSource, SearchProvider),
  feature flags, local stores for shortcuts, recents and favourites, and
  adapters that read the existing data layer without changing it.
- App shell: adaptive layout with bottom navigation and rail, global trip
  dock, banner and toast slots, debug component gallery (release-stripped).
- Router and web shell: new routes, fade-through transitions, inline HTML
  splash, pt-BR meta tags, updated PWA manifest.
- StaticLine now also exposes terminals, area tags and is_active;
  static-data loading is unchanged.
- New UI screens: home (Início) with shortcuts, live section and recents, local
  search, lines list with URL filters and favourites, the line screen with
  map plus draggable sheet plus timetable tab, the trip flow with chooser,
  consent, permission cards and trip screen with end card, settings with
  theme, data saver and reduced motion, privacy center reusing the existing
  delete and revoke actions, about, system states, and the global trip dock
  that stays live through controller notifications.
- Cutover: every legacy screen deleted with its tests; shared copy moved to
  the new strings file (two accent typos fixed, repository URL corrected to
  the actual remote); journey, share-flow, controller, auto-end and remote
  config tests migrated to the new UI; three pre-existing controller test
  failures fixed on the test side (frozen timestamps, pacing assumptions).
- Nine UI defects found by the new tests and fixed: stale dock snapshots,
  missing global idle pill, provider writes in widget life-cycles, ref reads
  in dispose, scroll clearance under the floating dock, AnimatedSwitcher
  timing, MediaQuery versus view size in tests, lazy sheet rows, and the
  consent double-sheet.
- T01 repo skeleton done (README, CHANGELOG, gitignore, SECURITY, templates, env examples). Restored `app/` directory.
- T02 Flutter shell done (Flutter 3.47.6, applicationId `com.spotnik.pontual`, strict analyzer, empty ProviderScope app, smoke test).
- T03 CI done (pinned actions, analyze plus format plus test, manifest audit, web size report, gitleaks; deno job lands in T06).
- S1 and S2 spikes done (geolocator 14.1.1 plus FGS findings; Deno 2.9.7 plus Hono 4.13.12 plus postgres.js 3.4.9 plus dbmate and Cloudflare findings).
- S3 and S4 spikes done (flutter_map 8.3.2 plus 50 MB cache plus OSM policy; --wasm plus no-CDN plus wake lock findings).
- T06 server skeleton done (Deno 2.9.7, Hono 4.13.12, fail-fast config, health plus metrics, CI server job).
- T07 database done (migration 0001, repositories, runtime config loader, no_location_at_rest, CI postgres plus dbmate).
- T08 security middleware done (Valibot 1.5.0, token auth, device plus consent plus delete routes, AC01 plus AC03 plus AC11 plus AC13 plus AC18 plus AC23).
- T09 pure engine done (attach plus election plus tick plus snapshot, tests 1-18 and 20-24).
- T10 trip endpoints done (start plus ping plus delete, quotas plus resume plus kill switch, AC02 plus AC07 plus AC09 plus AC10 plus AC14).
- T11 background jobs done (guarded tick plus config refresh plus purge plus db health, restart test 19).
- T12 reads and stream done (vehicles snapshot plus ETag, live lines, WS hub with caps plus heartbeat plus bye, AC05 plus AC06 plus AC08).
- T13 simulator done (buses plus riders plus abuse plus latency report, immediate position broadcast, CI smoke).
- T14 data pipeline done (JSON Schemas plus validator plus builder plus bundle loader plus CI data job).
- T15 line seed done (21 urban lines, 4 pilots with timetables, sources recorded).
- T16 static deploy files done (Pages _headers plus deploy workflow; project, DNS, and secrets owner-blocked).
- T17 route tool done (GPX/GeoJSON to simplified GeoJSON plus polyline bundle plus server decode; real traces owner-blocked).
- T18 app foundation done (theme tokens plus strings plus router skeleton, 200 percent scale green).
- T19 client core done (Clock plus Log plus geo plus backoff plus Result, 97 percent coverage).
- T20 net base done (keep-alive client plus token store plus on-demand registration).
- T21 typed API done (DTOs plus error mapping plus fake and live contract tests).
- T22 static repository done (bundled assets plus cache plus conditional GET plus atomic swap).
- T23 remote flags done (config repository plus S13 screens plus S14 banner).
- T24 home screen done (search plus cached list plus live dots, no spinners).
- T25 timetables done (day types plus origin selector plus next departure plus disclaimer).
- T26 map widget done (TileSource seam plus capped cache plus bounds plus attribution).
- T27 vehicle stream done (snapshot plus socket plus watchdog plus polling fallback plus stop).
- T28 map tab done (status states plus markers plus list rows plus recenter plus polyline).
- T29 trip domain done (state machine plus sampling policy plus auto-end, all transitions covered).
- T30 consent done (S06 sheet plus S07 sheets plus versioning plus offline-tolerant flow).
- T31 location done (geolocator stream plus FGS notification plus filters plus manifest permissions).
- T32 ping sender done (in-flight 1 plus latest-wins plus backoff plus 401 refresh plus server codes).
- T33 trip controller done (full lifecycle plus S08 screen plus S09 end cards, local E2E green).
- Share-trip flow wired (MapTab entry, consent plus permissions, /trip serves the started controller, fallback otherwise).
- T36 web build done (Pontual PWA manifest, self-hosted assets, wasm dual build, first load inside 3 MB budget).
- T38 web sharing done (Screen Wake Lock via wakelock_plus, foreground banner, 60 s hidden pause; JS path inside size budget, wasm path 3 percent over).
- T39 iOS install hint done (one-time Safari share-sheet card on iOS web).
- Android web download hint done (one-time native-app card on Android web, Baixar app downloads the latest release APK; release workflow also builds and uploads the universal APK).
- T40 settings and about done (theme with persistence, help, timetable date, sources, OSM attribution, licences, repo link; contact hidden until INFRA-23).
- T41 privacy center done (bundled policy/terms, 6-line summary, delete-my-data end-to-end AC13, revoke consent; support code cut per cut order).
- T42 privacy docs done (policy and terms drafts pt-BR, RIPD-lite, data inventory; lawyer review and contact still owner-blocked).
- T43 security review done (docs/security/review-alpha.md; all suites green; no open P0/P1 in code; VPS, release-build, and browser items recorded as blocked).
- T44 budgets measured where host allows (docs/field-tests/budgets.md; ping wire 0.62 KB, leader at budget, web JS path inside; AAB and on-device items TODO).
- T45 release hardening done (R8 minify/shrink with stock keeps, allowBackup=false, audit script extended, release-android.yml with merged-manifest audit and AAB size gate; keystore and first tagged build owner-blocked).
- T49 pilot kit done (docs/field-tests/pilot-kit.md; organizer contact still owner-blocked).
- T50 ops runbooks done (docs/runbooks/ops.md; kill-switch drill executed on an isolated local instance with readings intact).
- T05 deploy files done (server/deploy/pontual.service with the 12.8 sandbox, deploy.sh with checksum plus migrate plus health-gated swap plus rollback; keystore, uptime-monitor service, and first VPS run owner-blocked).
- T46 soak restarted clean after a self-inflicted contamination (test teardown fix in AC14; first run discarded, no code finding).
- Recorded owner answers round 1 in DECISIONS.md (D22-D28).

# Changelog

Format: Keep a Changelog. Current app version: `0.3.1`.

## [Unreleased] - 0.3.1

- Production domains: app at `https://pontual.spotnik.space` (GitHub Pages
  custom domain) and API at `https://api-pontual.spotnik.space` (Cloudflare
  Tunnel). Fixed the missing DNS record and the API CORS allow-list. See
  DECISIONS.md INFRA-05.
- CI: `deploy-static` and `release-android` resolve `STATIC_ORIGIN` from the
  Pages custom domain when the repo variable is unset, and `deploy-static`
  checks that the built web bundle contains the resolved API origin.
- Web PWA: `deploy-static` accepts optional `FIX_ACCURACY_MAX_M` and
  `FORCE_PING_BUTTON` repo variables for the temporary easy-test server.
  Defaults remain 60/false; remove them before the pilot.
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

Earlier alpha tasks T01-T50 and spikes S1-S4 are complete; see git history and DECISIONS.md for details.

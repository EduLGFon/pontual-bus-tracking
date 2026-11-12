# Changelog

Format: Keep a Changelog. Current app version: `0.3.1`.

## [Unreleased] - 0.3.1

- App copy: humanized the pt-BR deck and bundled privacy/terms summaries, moved inline widget copy into the deck, unified passenger reports to "Avisar/Aviso", and fixed privacy, permission and notification wording. Owner-approved legal rewrite with all disclosed facts preserved; lawyer review still pending. See DECISIONS.md D108.
- Sharing screen: minimalist `/trip` with the hero trimmed to live state, line and elapsed time, one compact status line that opens the full metrics sheet, and a pinned full-width "Avisar problema" action. No new report kinds or API change. See DECISIONS.md D105.
- Ping cadence: sends are scheduled from the last send start at the server interval, in-flight fixes wait for the next slot, and the live map rebuilds on throttled repository changes instead of only the 5 s age tick. Fixes 7-11 s gaps and 3-4 s bursts; the server keeps its 4 s defense and now exposes an `rl` flag plus an aggregate counter. See DECISIONS.md D106.
- Learning: corrected the data-learning docs, added a read-only deploy preflight that refuses a new or empty PostgreSQL volume unless explicitly allowed, and added aggregate-only drop-reason counters. No schema, threshold or publication change. See DECISIONS.md D107.
- UX 2.0 answer-first pass: first-run line picker, "Sua próxima saída" hero
  on Início, actionable share card, line hero with the leave-now walk verdict,
  lines/search status line and search entry, and the shell active trip bar
  replacing the idle floating dock. UI and copy only, with no new dependency
  and no new network or location behavior. See DECISIONS.md D104.
- Line and timetable screens now use the São Mateus wall clock once; a double
  conversion could show a past departure as the next bus. The Início live chip
  also hugs its content again. See DECISIONS.md D104.
- Server: Docker image and Compose deployment with a container-only public
  edge. Compose runs `db`, `migrate`, `api` and `cloudflared` services over
  two internal networks (`edge`, `data`) plus a non-internal `egress` network; the API has no
  published port and is reachable only by `cloudflared` on `edge`, metrics and
  PostgreSQL stay internal, and the tunnel is outbound-only with no host Caddy
  or systemd unit. The API image is multi-stage on a pinned Deno base, builds
  the static data bundle, runs as non-root on a read-only filesystem with all
  capabilities dropped and `no-new-privileges`, and takes secrets from env files plus a locally managed tunnel config and
  credentials. Rollback is by image tag via deploy.sh. See
  DECISIONS.md D101 and D102 and docs/runbooks/docker.md.
- Line screen: personal arrival at the rider's stop. The rider opts in with one tap; the app snaps to the nearest learned stop and shows the next bus ETA from the existing server ETA endpoint, with confidence and sample count. Location is one-shot and foreground-only, only line id and stop id are requested, and the viewer location no longer prompts on mount. See DECISIONS.md D96 and docs/ui/personal-arrival.md.
- Trip sharing cadence: every role (`waiting`, `leaderMoving`, `leaderStill`,
  `follower`) now samples and pings every 5 s; offline saver and paused keep the
  45 s power-saving cadence. Follower jitter is removed so the server
  instruction is exactly 5 s, and the next send slot is measured from the send
  rather than the response so a slow round trip cannot halve the cadence. See
  DECISIONS.md D94.
- Location stall watchdog no longer recreates the position stream when a run of
  coarse fixes is filtered out or when a slow power mode is between fixes, which
  was stopping and restarting the Android foreground service every ~30 s. See
  DECISIONS.md D93.
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

- Trip sharing: the app no longer recreates the Android location stream while backgrounded, which Android 14+ rejected as a forbidden foreground-service start and silently killed trips from the field bundles. Background stalls and mode changes wait for the next resume with one recovery attempt, foreground retries are capped at one per stall window, coarse fixes count as alive, and a dead or never-started stream now fails the trip visibly with the service reason instead of showing sharing. Uncaught "No active stream to cancel" errors and the stop/relisten race are fixed. No new permission, wake lock, or dependency. See DECISIONS.md D99.
- First-party diagnostics: bundles now carry the real build (CI injects the pubspec version), platform and OS, a random per-bundle id that is stable across retries, and a crash payload with the exception, widget context, and a truncated stack. Persisted writes are serialized, a cold start uploads after a short debounce as well as on resume, and a successful upload no longer drops records written while it was in flight. The server accepts the optional bundle id additively. See DECISIONS.md D99.
- Trip screen layout: the content and header scroll while Desci stays pinned, and the end card scrolls, so neither overflows on small screens with large text. Regression test covers 320x568 at 2x text scale. See DECISIONS.md D99.
Earlier alpha tasks T01-T50 and spikes S1-S4 are complete; see git history and DECISIONS.md for details.

# Sharing screen redesign - audit and plan

Audit of the `/trip` sharing screen (`Compartilhando viagem`) against
`trip.md`. Code references are to `app/lib` at HEAD `88ed158`.

## Current structure

- `ui/features/trip/trip_screen.dart`: `TripRoute` attaches the started
  `TripController` to `tripHostProvider`, detaches on dispose when idle.
  `_body` is `Column[header, Expanded(SingleChildScrollView(TripHero)),
  StatusBlock, DangerButton]`. System back is intercepted (`PopScope`
  `canPop: false`) and calls `context.pop()`, so back minimizes.
- `ui/features/trip/trip_hero.dart`: `LivePulse > LiveDot(live, 14)`,
  headline `Você está ajudando quem espera o ônibus`, line badge plus
  `controller.lineLabel`, `_ElapsedClock` ticking every 1 s showing
  `HH:MM:SS`.
- `ui/features/trip/trip_status.dart`: three `_StatusRow`
  (connection, GPS, device/role), offline banner, GPS-off banner with
  `Ativar GPS` action, Android battery tip, web banner plus web note.
- `features/trip/trip_controller.dart`: owns consent, permission,
  registration, first fix, ping loop paced by `_nextPingAtMs`, supervisor
  rounds every 30 s, best-effort `endTrip`. Exposes only `isOffline`
  (role `offlineSaver`), `isPaused` (supervisor GPS-off), `startedAtMs`,
  `lineId`, `lineLabel`, `isWebHidden`.
- `features/trip/trip_supervisor.dart`: tracks `_lastSuccessMs`,
  `_gpsOffSinceMs`, `_permissionRevoked` (after 3 bad polls),
  slow-speed clock, offline rule (3 failures or 120 s silence).
- `features/trip/ping_client.dart`: one request in flight, latest-wins
  coalescing. Comment on retry: `never queue history`. Offline fixes are
  dropped, not stored.

## Root causes of the reported bugs

1. Duplicate offline sentence. When `isOffline`, `_roleRow` returns a
   device row whose value is `roleOffline`
   (`Sem conexão. Vamos retomar assim que voltar.`) with the default
   `good: true`, and the banner below shows the same `roleOffline`
   string. One sentence appears twice by construction.
2. Green lies. The offline device row above uses the default
   `good: true`, so the offline text renders in `liveText` green.
   The web brightness tip row uses `good: !wakeUnsupported`, so an
   informational tip renders green when the wake lock works. Green
   currently means "default", not "OK".
3. Narrow right value column. `_StatusRow` is
   `Row[icon, Expanded(label), Flexible(right-aligned value)]`. Long
   values (`Sem conexão. Tentando de novo`, `roleOffline`) wrap to 3
   lines in a cramped column. Fix is value-under-label tiles, not a
   wider column.
4. Tip duplication on web. `_webNote` renders `WebTripBanner`
   (keep-open copy) plus a `_StatusRow` labelled `webKeepOpen` with
   value `webBrightness`. Same keep-open sentence appears twice, once
   as label and once as banner.
5. No header `Stack` overlap in the current tree. There is no `Stack`
   or `Positioned` in `trip_screen`, `trip_hero` or `trip_status`; the
   pulse is a bounded `LiveDot` inside its own `SizedBox`. The clipped
   pulse in the brief screenshot matches an older header and is
   already gone. Remaining layout risk is overflow, not overlap: only
   the hero scrolls, `StatusBlock` plus the stop button are fixed, so
   large text can overflow below the hero instead of scrolling above
   a pinned button.
6. Stop button copy and style. Label is `Desci - encerrar viagem`
   (`endTrip`), not the specified `Desci do ônibus`. `DangerButton`
   is a 12 percent danger fill with `dangerText`; contrast on the
   translucent fill is checked in the contrast follow-up below.

## Truth audit (what the copy may claim)

- Offline queueing: FALSE to claim backlog. `PingClient` keeps only
  the latest fix and drops the rest, so positions missed while
  offline are lost. `Sem conexão. Vamos retomar assim que voltar.`
  (resume, not backlog) is accurate and must stay worded that way.
- `Encerra a viagem e para de enviar sua posição.` TRUE: `endTrip`
  stops the stream and service locally first, then best-effort ends
  on the server with a 5 s timeout, so stopping works offline.
- `Anônimo. Só a posição do ônibus, sem nome nem conta.` TRUE:
  device token is opaque, viewers see merged vehicles only.
- Wake lock: Android holds no `wakelock_plus`; sharing survives
  screen-off through the geolocator foreground service with a
  persistent notification. Web holds `ProdWebWakeLock` only while
  `TripScreen` is mounted (`enable` in `initState`, `disable` in
  `dispose`) plus a 60 s hidden-pause tracker. Gap: minimizing the
  web trip disposes the screen, which releases the wake lock and
  cancels the visibility timer while the controller keeps running
  in the host. Reopening re-acquires. No leak on the normal
  start, stop, error, dispose paths; the minimized-web case loses
  protection instead of leaking it.
- Thresholds found in code: fix drop `accuracy > 60 m`
  (`fixAccuracyMaxM`), stale fix age 20 s, offline after 3 failures
  or 120 s silence, GPS-off end after 5 min, permission revoked
  after 3 bad polls, slow prompt after 15 min below 0.5 m/s, hard
  cap 4 h. No weak-GPS tier, no low-battery tier, no stale-send
  amber tier. New thresholds are defined once in the health model
  file and listed in the final report.

## Missing pieces vs trip.md

- No `resolveSharingHealth` pure function; rows compute copy inline.
- No last-send text; `_ElapsedClock` ticks every second (battery
  cost) and shows `HH:MM:SS`, not `há 12 min`.
- No direction chip; only `lineLabel` plus badge, no terminals.
- Live dot always live-pulsing, even offline or paused.
- No starting neutral state (`Iniciando...` / `Procurando sinal`);
  start jumps from progress sheet to active.
- No debounce (3 s grace at startup, 2 s banner hold).
- End card is `Viagem encerrada...` plus `Voltar às linhas` with no
  auto-dismiss; brief wants `Concluído` plus ~3 s auto-dismiss then
  return and FAB reset.
- Minimize keeps sharing (verified in code: `detachIfIdle` keeps a
  live controller, dock reads it via `tripVmOf`, settings has a
  sharing banner). Every-screen FAB coverage is verified by test,
  not by hand, on this host.

## Implementation order (one commit each)

1. `resolveSharingHealth` pure model plus unit tests (V2).
2. Read-only controller signals the model needs (V2 wiring).
3. Layout invariants: single banner, tiles with value under label,
   one tip, no duplicate sentence (V1, V3).
4. Pinned stop action with honest caption (V4).
5. Line, direction, elapsed, last-send, trust line (V5).
6. Truthful live indicator (V6), problem states through the model
   (V7), startup debounce (V10), minimize check (V9), keep-awake
   tip plus wake audit (V8).
7. Theme and contrast check (V11).

## Final report (implemented 2026-10-12, commits 81d7b64 to 330bd16)

### What changed

- New pure model `app/lib/domain/trip/sharing_health.dart`: tile
  codes plus levels for `Conexão`, `GPS`, `Seu celular`, one
  `primaryIssue`, overall `starting`, `live`, `paused`, `ended`.
  Priority: permission, location off, offline, GPS, low battery.
- Read-only wiring only, no behavior change:
  `TripController.lastSuccessMs`, `lastAccuracyM`, `lastBatteryPct`,
  `lastCharging`, `permissionRevoked`, `servicesOn`,
  `sharingSignals`, memoized `sharingHealth`;
  `TripSupervisor.lastSuccessMs`, `permissionRevoked`.
- `trip_status.dart` rewritten: value-under-label tiles (row on
  600 dp and wider, stacked otherwise), one debounced banner (2 s
  hold, startup grace 3 s), one neutral keep-awake tip. The Android
  battery-optimization banner was removed from this screen (second
  tip); it still lives under Settings battery tips.
- `trip_hero.dart` rewritten: truthful indicator (green pulse live,
  static amber paused, neutral starting and ended, bounded box),
  `Iniciando...` state, badge plus name plus endpoints chip,
  `há 12 min` elapsed, `Última posição enviada há 8 s` proof line
  (amber when stale), trust line. Times tick on a coarse 5 s timer
  instead of every second.
- `trip_screen.dart`: single scroll region above a pinned stop
  block (caption plus `Desci do ônibus`, 56 dp, never disabled,
  semantic label `Encerrar viagem e parar de compartilhar`).
- `trip_end_card.dart`: `Concluído` action, returns to the previous
  screen, auto-dismisses after about 3 s.
- `DangerButton` gained an optional `semanticLabel` (additive only).
- Copy additions in `UiStrings` (short tile values, banners,
  `agoShort`, `agoLong`, trust and tip lines).

### Files touched

`domain/trip/sharing_health.dart` (new),
`features/trip/trip_controller.dart`, `features/trip/trip_supervisor.dart`,
`ui/features/trip/trip_status.dart`, `trip_hero.dart`, `trip_screen.dart`,
`trip_end_card.dart`, `ui/design/components/buttons.dart`,
`ui/strings/ui_strings.dart`, tests `sharing_health_test.dart` (new),
`sharing_signals_test.dart` (new), `ui/trip_screen_test.dart` (new),
`ui/trip_settings_test.dart`, `trip_controller_test.dart`,
plus this document.

### Decisions and trade-offs

- Health model returns codes, not sentences; widgets map codes to
  `UiStrings`. Keeps one copy source per AGENTS.md 5.
- Banner hold (2 s) and startup grace (3 s) implemented as
  `IssueDebouncer` plus model-side grace; banner has no entrance
  animation (reduced-motion safe by construction).
- New thresholds in one file: weak GPS above 30 m (drop stays
  60 m), stale send above 45 s, low battery at or below 15 percent
  while unplugged. Charging exempts low battery.
- Endpoints chip shows both terminals (`Litorâneo · Aviação`);
  per-trip direction is not captured anywhere (direction sheet is
  out of scope), so no live `Sentido X` claim is made. See gaps.
- `DangerButton` 12 percent fill already reaches 4.5:1 (light 5.06,
  dark 7.02, computed); no new theme tokens were needed, so no
  tonal container was added.
- Offline copy keeps the resume wording (`Vamos retomar assim que
  voltar`) because `PingClient` drops history by design
  (latest-wins); nothing claims backlog delivery.
- Dim battery-saving view (V8 optional) skipped: web minimized
  trips already lose the wake lock (gap below), and a near-black
  overlay adds risk without measured gain.

### Size and performance numbers

- No new dependencies. Expected bundle delta near zero (not
  measured here: no Android SDK on this host for AAB, web build
  not re-run;CI `release-android.yml` and web size gates cover it).
- Screen now owns one 5 s text timer plus the shared pulse
  controller (paused under reduced motion or `TickerMode` off);
  health resolution is memoized on identical inputs.
- `flutter analyze` clean. Targeted suites green (sharing,
  controller, settings, layout). Full `flutter test`: 342 passed,
  1 skipped, 0 failed.
- `dart format` clean on all touched files. Note: local Flutter
  3.47.7 reformats two untouched files (`trip_flow.dart`,
  `trip_flow_test.dart`); reverted as unrelated drift, CI pins
  3.47.6. Manifest source audit PASS.

### Gaps found

1. Web minimized trips lose protection: disposing `TripScreen`
   disables `ProdWebWakeLock` and cancels the visibility timer
   while the controller keeps running in the host. Reopening
   re-acquires. No leak on start, stop, error, dispose.
2. No per-trip direction stored (`lineLabel` is the line name);
   the chip lists both endpoints instead of a live sense.
3. Reopened screen reads the controller synchronously (no stale
   flash), except the line badge which waits on `linesProvider`.
4. Every main screen shows sharing through `LiveDockHost` plus the
   Settings sharing banner; verified in code and by the minimize
   widget test, not by hand on a device.

### Recommendations (out of scope)

Foreground service with persistent notification so the phone can
lock during the trip (Android already uses the geolocator
foreground service; the tip discount stays until then), auto-stop
after long inactivity or far-from-route, adaptive update
frequency. The skipped dim view can be revisited with measured
numbers.

### Needs owner input

- Confirm the three new thresholds (weak 30 m, stale 45 s, low
  battery 15 percent).
- Anything in the brief that conflicts with PLAN.md or AGENTS.md:
  none found; the brief was followed except the documented
  endpoints-chip and dim-view deviations above.

## Metrics pass (2026-10-20)

The trip screen now renders measured values instead of three short words.
`ui/features/trip/trip_metrics.dart` replaces the old `StatusTiles` with a
single `SurfaceCard` holding three metric cells:

- **GPS**: accuracy from the last accepted fix (`±8 m`) and a meter
  against the existing 60 m publish gate (`fixAccuracyMaxM`). No fix shows
  the searching copy; off, no permission and approximate grants keep their
  explicit states.
- **Satélites**: satellites used (`7`) and in view (`de 12 em vista`) from
  the Android GNSS channel, with a meter built from that real fraction.
  When the receiver sees none, the cell says so; on platforms without the
  native channel it reads "Indisponível no navegador" instead of waiting
  forever.
- **Envio**: the server interval in seconds (`15 s`) plus the role
  explanation (waiting, leader, follower, offline). The stale-send tier
  turns the caption amber after 45 s. There is no meter because no honest
  denominator exists.

Missing values are named, never filled with a placeholder number. The
panel stacks below 600 dp and whenever the text scale exceeds 1.3; above
that the three cells sit in one row inside the same card. Each cell has a
combined screen-reader sentence, and colour is never the only signal.

Data sources are unchanged: accuracy, satellites and GNSS quality already
existed; `TripController.role` and `TripController.intervalS` are
read-only getters. A 5 s tick in `StatusBlock` refreshes values that
arrive on accepted fixes or native samples without a controller
notification. Battery was removed from this card: the low level still
raises its own banner, but the percentage was noise here. No new
dependency, permission, field, log or persisted value was added.

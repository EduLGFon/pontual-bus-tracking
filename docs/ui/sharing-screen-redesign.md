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

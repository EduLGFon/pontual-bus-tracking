# Settings redesign: audit and report

Audit of the current `Ajustes` implementation against `settings.md`.
Code, comments, commit messages and docs are in English. User-visible
strings are pt-BR.

## Audit (2026-10-12)

### Current implementation

- Screen: `app/lib/ui/features/settings/settings_screen.dart`
  (`SettingsScreen`). Title `Ajustes` uses `context.text.display`.
  Section headers use shared `SectionHeader` with `context.text.title`
  (22 pt). `Tema` label uses `context.text.label` with a left offset of
  `Space.x1`. Version line uses symmetric `Space.x1` padding, so `Tema`
  and the version line start further right than the rows.
- Rows: private `_Row` (icon, label, chevron) and `_SwitchRow` (label,
  optional hint, `Switch`). `SettingsRow` in `settings_row.dart` is the
  shared equivalent of `_Row` (used by privacy and about screens).
  Switch rows are not whole-row tappable and have no minimum height.
- Theme: `themeHostProvider` (`ThemeHost` in
  `ui/design/adapters/theme_bridge.dart`) persists through
  `data/prefs/theme_store.dart` (`theme_mode`, default system).
  `main.dart` loads the saved mode after the first frame, so a saved
  dark or light choice flashes from system on cold start.
- Settings storage: `ui/adapters/local_stores.dart` (`SettingsStore`,
  `settingsProvider`, `UiSettings`). Keys `ui_data_saver_v1` (bool,
  default false) and `ui_reduce_motion_v1` (bool, default false).
  Changes apply and persist immediately, no save button.
- Data saver consumers (every read of the flag):
  - `ui/features/line/line_screen.dart`: `showMap = _mapOpened ||
    !dataSaver`. With the flag on, the line opens as a list and the map
    loads only after `Ver no mapa`.
  - `ui/features/line/viewer_location.dart`: returns null when the flag
    is on, so no one-shot viewer position is requested (power saving,
    no camera move to the viewer dot).
  - No other readers. In particular there is no refresh-rate change, no
    prefetch change and no tile-preloading change.
- Reduce motion consumers (every read of the flag or of
  `MediaQuery.disableAnimations`):
  - `LivePulse` (`ui/design/components/live_pulse.dart`) pauses the
    shared pulse when `MediaQuery.disableAnimations` is true. It does
    not read the app setting.
  - `line_screen.dart` `_onTabChanged` and `timetable_tab.dart`
    `_scrollToNext` jump instead of animating when
    `MediaQuery.maybeDisableAnimationsOf` is true. They do not read the
    app setting.
  - The router fade-through (`page_transition.dart`) shortens to instant
    with no slide when the system flag is true. It does not read the app
    setting.
  - `motionDuration` helper exists in `ui/design/tokens/motion.dart`
    but has no callers. `Segmented` thumb (`AnimatedAlign`),
    `Pressable` (`AnimatedScale`, `AnimatedContainer`), `BannerSlot`
    (`AnimatedSize`), nav pill tint, sheet snap durations, skeletons,
    `LiveDot`/marker interpolation and the trip elapsed ticker ignore
    both the system flag and the app setting.
- Timetable date source:
  - `timetableDateProvider` in `app/providers.dart` reads
    `assets/data/manifest.json` (`generated_at`) and formats
    `dd/MM/yyyy`. Current bundle value is `2026-10-03T00:52:47.112Z`,
    shown as `03/10/2026`.
  - Settings footer and `line_sheet.dart` (passed to `timetable_tab.dart`
    footnote `Horários não oficiais. Atualizado em <date>`) read the
    same provider. There is one source of truth in code today; the two
    dates in the brief (`03/10/2026` vs `11/10/2026`) come from a stale
    screenshot, not from two datasets. No hardcoded date in widgets.
  - Footer today: `versão 0.1.0 · Horários: 03/10/2026` with `appVersion`
    (`0.1.0` in `data/config/remote_config.dart`, a compile-time
    constant, not package info).
- Sharing state: `tripHostProvider` (`ui/shell/trip_host.dart`) holds the
  active `TripController` or null. `LiveDockHost`
  (`ui/shell/dock_host.dart`) renders the global dock; `AppShell`
  (`ui/shell/app_shell.dart`) mounts it on every tab, including
  settings. Stopping uses `TripController.endTrip` (best-effort server
  end plus local teardown). Line label comes from
  `controller.lineLabel` via `tripVmOf` (`ui/adapters/trip_adapter.dart`).
- Local storage keys that `Limpar dados locais` must consider
  (`SharedPreferences`, all local-only):
  - `ui_shortcuts_v1`, `ui_recents_v1`, `ui_favorites_v1`,
    `ui_alerts_v1`, `ui_kudos_v1`, onboarding keys in
    `ui/features/home/welcome_state.dart`, `installHintSeenKey`,
    `androidAppSeenKey`, static-data cache keys (`manifestKey`,
    versioned lines), remote-config cache, consent store, token store.
  - Keep: `theme_mode`, `ui_data_saver_v1`, reduce-motion setting.
  - Never touch: the live `TripController` (sharing state).
- Attributions (`ui/features/settings/about_screen.dart`): disclaimer
  present, `onibus.online` source line present, OSM row opens
  `https://www.openstreetmap.org/copyright`, licences row opens
  `showLicensePage`, repo row present. S10 is verification only.
- Privacy summary claim (`Sem cadastro. Sua localização só é usada
  enquanto você compartilha.`): true in code today. There is no sign-up
  (`UiStrings.homeNoLiveHint` states `sem cadastro`), location leaves
  the device only through trip pings while a trip runs
  (`TripController` owns all sends), and the viewer position
  (`viewer_location.dart`) never leaves the device.
- Switch styling: `theme.dart` defines no `SwitchThemeData`, so stock
  Material 3 switches render. Off track/thumb are close in tone to on
  at a glance.

## What changed (per commit)

- `fix(settings): single source for timetable date` (S9): footer uses
  the shared date provider with the `Horários atualizados em`
  wording. No second dataset exists; both screens already read the same
  provider.
- `feat(settings): shared section and tile widgets` (S3, S4): new
  `settings_section.dart` with `SettingsSection` (small muted header,
  optional footer) and `SettingsTile` (icon, title, description,
  trailing switch/chevron/value, 56/72 dp rows, one left edge, one
  `ListView`).
- `fix(settings): readable switch states` (S2): app-wide
  `SwitchThemeData` (muted outline off, filled accent on), whole-row
  tap target with `Pressable` feedback (project uses tint, not Material
  ripple, per `theme.dart` `NoSplash`; see conflicts), single-switch
  semantics announcing `ativado`/`desativado`.
- `feat(settings): theme control polish` (S11): icons on the three
  theme segments via the shared `Segmented` control, filled selected
  state, 48 dp minimum. Cold-start theme flash is a reported conflict
  (PLAN `main.dart` boots before prefs load); the saved choice still
  loads right after the first frame.
- `feat(settings): regrouped sections` (S5): `Aparência`, `Dados e
  desempenho`, `Privacidade e ajuda` (with the verified one-line
  summary), `Sobre`. Existing destinations kept.
- `fix(settings): data saver copy matches behavior` (S6): description
  lists exactly what the flag does (list-first map, no viewer position
  lookup).
- `feat(settings): reduce motion description and helper` (S7):
  description added, three-state stored value (system/on/off) shown as
  a switch, `AppMotion.duration` helper. Only trivial wiring;
  everything else is listed under gaps.
- `feat(settings): clear local data` (S8): `Limpar dados locais` row,
  confirmation dialog with the exact removal list, `Dados locais
  removidos` feedback, settings kept, sharing untouched, offline-safe.
- `feat(settings): no dock on settings plus sharing banner` (S1):
  `AppShell` hides the global dock on the settings branch (default
  unchanged elsewhere); the banner shows the live line with `Parar`
  while sharing.
- `docs(settings): attributions check` (S10): verified reachable, no
  code change needed.

## Decisions and trade-offs

- Ripple vs tint (S2 vs `theme.dart`): the brief asks for a ripple on
  switch rows. The project sets `NoSplash.splashFactory` globally and
  uses `Pressable` tint plus scale for every tappable element. Adding a
  Material ripple to one screen would create a second interaction
  language. Kept `Pressable`; rows still meet the 56 dp target and the
  single-switch semantics.
- Shared `SectionHeader` untouched: it renders `title` style (22 pt)
  and is used by other screens. Settings uses its own small muted
  header so Home/Lines keep their look (brief rule 7).
- Theme flash (S11 vs `main.dart`): `main.dart` intentionally runs
  before prefs load (PLAN 8.4, first paint never waits). Moving the
  theme read before the first frame would delay every cold start for
  one screen. Kept the current boot order and reported the flash as a
  known gap instead of regressing startup.
- Reduce-motion storage: the old bool key stays readable. Unset means
  follow system; an explicit write stores `system`, `on` or `off`.
- Clear-data scope: clears favorites, recents, shortcuts, alerts,
  kudos, onboarding and install-hint flags, and the static/remote
  caches. Keeps theme, motion and data-saver settings, consent record,
  device token and the live trip. Consent and token are auth-adjacent,
  not disposable cache; deleting them would log the device out of its
  sharing identity, which is the job of `Apagar meus dados`, not of
  this row.
- Footer version: still the `appVersion` compile-time constant, not
  package info (no new dependency, no async version lookup on a
  no-network screen). Wording changed to the requested
  `Pontual 0.1.0 · Horários atualizados em <date>`.

## Size numbers

Not measured on this machine per owner instruction (no flutter
analyze/test/build here). Expected delta near zero: no new
dependencies, no images, no new fonts, one small widget file plus
strings. Measure before/after on the capable machine (`flutter build
appbundle`, `flutter build web --release`).

## Gaps found

- Data saver is consumed only by the line screen list-first map and the
  viewer-position lookup. It does not change live refresh rate,
  prefetching or tile preloading.
- Reduce-motion app setting is honored only where wired in this change
  (settings switch effective value, `AppMotion` helper, line sheet tab
  snap). The system flag was already honored by `LivePulse`, the router
  fade-through, the sheet snap and the timetable rail auto-scroll.
  Still ignoring the app setting: router fade-through, `Segmented`
  thumb, `Pressable` scale/tint, `BannerSlot` size, nav pill tint,
  timetable rail auto-scroll, skeletons, `LiveDot`/marker
  interpolation, trip elapsed ticker. `LivePulse` honors the system flag
  only, not the app setting.
- Cold-start theme flash: a saved non-system theme applies after the
  first frame, not before.
- Footer version is a compile-time constant, not package info.

## Recommendations

- Data saver extras (not implemented, would change behavior elsewhere):
  longer viewer polling intervals, no viewer-position lookup (already
  the case), smaller tile prefetch radius, lazy route polyline.
- Sharing preferences (need sharing-logic changes, out of scope):
  auto-stop after X minutes, update frequency choice.
- Wire `AppMotion.duration` through router transitions, sheet snaps
  and skeleton shimmer behind one setting check.

## Needs owner input

- `Report wrong timetable` destination (email, form or tracker): no row
  added, per the brief.
- Canonical policy/terms URLs and support contact (INFRA-23): unchanged.
- Whether the footer version should switch to package info (adds an
  async lookup or a new dependency) or stay a compile-time constant.

# Home screen redesign (home-screen.md brief)

Audit, implementation notes and final report for the Home (`Início`)
improvements. The brief is `home-screen.md` at the repo root. `AGENTS.md`
and `PLAN.md` take precedence over the brief where they conflict; every
conflict is listed in section 3 and recorded in `DECISIONS.md` (D29).

## 1. Audit: current implementation

Widgets involved (`app/lib/ui/features/home/` plus shared components):

- `home_screen.dart`: wordmark plus live chip (`_HomeHeader`,
  `_LiveSummaryChip`), greeting, `SearchEntry`, section slots,
  `SingleChildScrollView` with `dockClearance` bottom padding.
- `home_sections.dart`: `ShortcutsSection` (horizontal snap list),
  `SaindoAgoraSection` (next arrival per shortcut).
- `home_lists.dart`: `LiveNowSection`, `RecentesSection`,
  `NoLiveCard`, `AllLinesRow`.
- Shared: `TripDock`/`LiveDockHost` (global share entry point),
  `ShortcutCard`, `ArrivalRow`, `LineRow`, `LineBadge`, `EtaText`,
  `SectionHeader`/`GhostLink`, `SearchEntry`.
- Data: `linesVmProvider` (static lines plus `GET /v1/live` counts),
  `TimetableArrivalsSource` (bundled timetables, offline first),
  `currentNowProvider` (1-minute tick), `shortcutsProvider`,
  `homeRecentsProvider`, `offlineFlagProvider` (banner only).

Findings per brief item:

- C1 (FAB overlap): already resolved by architecture. There is no FAB;
  the global `TripDock` pill sits above the bottom nav and every
  scrollable branch reserves `dockClearance`. Home never requests
  location on load. No change needed beyond keeping the clearance.
- C2 (shortcut cards): confirmed. Labels are single-line with
  ellipsis, unknown states render `--`, live lines show no live
  state on the card.
- C3 (Saindo agora): confirmed. Title never switches, no dedupe, no
  row cap, and `ArrivalRow` joins `Litorâneo · Aviação` with
  `Aviação` into a duplicated subtitle. The dashed `Horário` button
  from the brief no longer exists (rows have no trailing action).
- C4 (live pill): confirmed. The chip always shows the green live
  dot, including for `0 ao vivo`, and has no offline state.
- C5 (empty state): partly confirmed. The card is fine in size but
  carries a `Ver horários` link that duplicates `AllLinesRow` below
  it, and has no trust line.
- C6 (recentes): partly confirmed. `Limpar` already has a 48 dp hit
  area (`Pressable` default) and token colors that pass the contrast
  test; the overlap from the brief is gone with the dock. Missing:
  item cap and undo for the destructive tap.
- C7 (greeting): confirmed, spacing is generous (two `Space.x4`
  gaps around the greeting block).
- C8 (countdown): tabular figures already on via `PontualText`;
  non-breaking spaces not applied.
- C9 (line colors): already done via `LineBadge` plus the
  deterministic palette in `line_colors.dart`. Skipped.
- C10 (offline): timetables already render from the bundled cache
  with no spinners; no cache-age line exists.

## 2. What changed

Pure helpers in `app/lib/ui/features/home/home_logic.dart` (unit
tested in `app/test/ui/home_logic_test.dart`):

- `dedupeSubtitleParts` / `joinSubtitle`: split on `·`, trim, drop
  empties and duplicates preserving order. `ArrivalRow` uses it, so
  `Litorâneo · Aviação · Aviação` renders `Litorâneo · Aviação`.
- `proximasSectionTitle`: `Saindo agora` only when the soonest
  departure is within 15 minutes, else `Próximas saídas`.
- `departureKey` / `liveKey` / `dropShownDepartures`: section
  dedupe. Timetable rows whose line, origin and time already appear
  on a shortcut card are dropped; at most 3 rows remain; an empty
  section hides.
- `resolveShortcutState`: explicit card states (upcoming, imminent
  under 10 minutes, live, no more today, no data). No `--` anywhere.
- `directionLabel`: derives a muted second line from existing data
  (`sentido <destino>` when the origin is known, else terminals).
- `firstDepartureTomorrow`: first departure of the next day for the
  `Amanhã 06:10` hint, derived client-side from bundled timetables.

Widgets:

- `ShortcutCard`: label wraps to 2 lines with a tooltip holding the
  full name; muted direction line; live state shows a live dot plus
  `Ao vivo`; imminent times use the primary accent; no-data states
  read `Sem mais saídas hoje` (plus tomorrow hint when known) or
  `Sem horário`; full-sentence pt-BR semantics on the card with the
  time texts excluded from the tree.
- `SaindoAgoraSection`: dynamic title, dedupe, cap of 3, whole-row
  tap unchanged.
- Live pill: `Nenhum ao vivo` with a neutral scheduled dot at zero,
  green dot with `N ao vivo` above zero, `Offline` with a stale dot
  when the offline flag is set. Semantics match the visible text.
- Greeting block: tighter spacing (`Space.x3`), subtitle pinned to
  one line.
- `NoLiveCard`: trust line with an icon (`Anônimo. Sua localização
  só é usada enquanto você compartilha.`); the `Ver horários` link
  is removed (navigation lives in `Todas as linhas` below).
- `Recentes`: shows at most 4 chips, hides when empty (unchanged),
  and `Limpar` offers `Desfazer` through the global toast instead of
  a dialog. `RecentsStore.write` and `RecentsNotifier.restore`
  support the undo.

Strings: all new copy lives in `UiStrings` (`homeLiveNone`,
`homeOffline`, `homeTrust`, `homeNoMoreToday`, `homeTomorrowAt`,
`homeNoTime`, `homeNoTimeHint`, `homeRecentsCleared`).

## 3. Brief conflicts and deviations (D29)

- C1 asks for an extended FAB. The app uses the global `TripDock`
  pill per `UI_SPEC.md` 7.1, which already fixes the overlap the
  brief complains about and owns the sharing-active state. No FAB
  was added; the dock behavior is unchanged.
- C2 asks for ~168 dp cards. Cards stay at the `Sizes.shortcutWidth`
  token (156 dp) per `UI_SPEC.md`; the 2-line label plus direction
  line fixes the reported indistinguishability without layout churn.
- C5/C6 ask for compact live rows with ages and for rows instead of
  chips. The live endpoint exposes counts only, so ages would need
  a contract change (forbidden by the brief); `LineRow` stays.
  Recents stay as chips per `UI_SPEC.md` 7.2, capped at 4.
- C8 asks for a shared 30-second ticker. The screen keeps the
  existing 1-minute `nowTickProvider`: countdowns are
  minute-granular, and a faster tick costs battery on the entry
  level phones in `PLAN.md` 3.3. Non-breaking spaces were not
  applied to `formatEta` because its unit tests pin regular spaces.
- C9 skipped: already implemented (`line_colors.dart`).
- C10 cache-age line (`Atualizado há X min`) skipped: needs
  cache-age plumbing through `StaticDataRepository`; documented for
  a follow-up.

## 4. Verification

- `flutter` is not installed on this machine (the old SDK symlink
  is broken), so `flutter analyze`, `flutter test`, screenshots and
  size profiling could not run here. They must run on a
  Flutter-capable machine before merge: `flutter analyze`,
  `flutter test app/test/ui/home_logic_test.dart`, the updated
  `home_screen_test.dart`, widget checks at 320/360/411 dp widths,
  200 percent text scale, and dark plus light themes.
- Added `app/test/ui/home_logic_test.dart` covering subtitle
  dedupe, title threshold, departure dedupe, state resolution,
  direction labels and the tomorrow lookup.
- Updated `app/test/ui/home_screen_test.dart`: a single non-live
  shortcut no longer renders the departures section (fully covered
  by its card), and a live shortcut renders the `Saindo agora`
  live row.
- No new dependencies, no new permissions, no new network calls, no
  logging of positions or identifiers. All colors come from theme
  tokens.

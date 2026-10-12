# Line detail screen polish (line-screen.md brief)

Audit, implementation notes and final report for the line detail
(`Linha`) improvements. The brief is `line-screen.md` at the repo root.
`AGENTS.md` and `PLAN.md` take precedence over the brief where they
conflict; every conflict is listed in section 3 and recorded in
`DECISIONS.md` (D32).

## 1. Audit: current implementation

Widgets involved (`app/lib/ui/features/line/` plus shared pieces):

- `line_screen.dart`: compact full-bleed map plus `DraggableScrollableSheet`
  (peek 0.30 min 220 dp, half 0.55, full 0.92, snap) and wide side panel
  above 600 dp (`LineExpanded`). Starts the vehicle stream for pilot lines
  only. Contextual `LineDock` pill floats above peek and fades past peek.
  Map layer is outside the sheet rebuild path (`RepaintBoundary`).
- `line_sheet.dart`: header, `Agora | Horários` `Segmented`, `TimetableTab`
  or Agora body (`liveHeroOf` hero `ArrivalRow`, `EmptyState` bus art when
  no vehicles, `VehicleRow` list capped at 5, `ReliabilityCard`,
  up to 3 next departures, `GhostLink` action row).
- `line_sheet_header.dart`: `LineBadge.ofLine` (category fills, no hardcode),
  2-line title, unconditional terminals line, `CertaintyBadge` plus
  subtitle (`homeNoLive` / `onlyTimetable`), non-pilot note,
  `LineStarButton` (48 dp `IconBtn`, generic semantics, no undo).
- `line_map.dart` plus `line_map_controls.dart`: `flutter_map` with
  `osmTileLayer` (real User-Agent, 50 MB cache cap), `mapBounds` plus
  min 12 / max 17 zoom, city fit when no vehicles, route casing plus
  stroke (empty until route data exists), `VehicleMarker` with heading
  triangle and selected state, viewer dot (drawn only, never sent),
  back plus attribution plus recenter controls, `mapScrim` tint (no
  `ColorFiltered`, no blur).
- `timetable_tab.dart` plus `timetable_data.dart`: day default from
  `dayTypeFor` (no holiday detection), `Segmented` day selector with no
  `hoje` mark and no muted empty tabs, `Chip` wrap origin selector with
  no per-line memory, `TimeRail` hour plus wrapping minute chips with
  past dim by color alpha and next highlight plus auto-scroll, hero
  shows `next` (D-U26), footnote uses `formatDateLabel(now)` plus
  `GhostLink` to `/about`.
- Shared reuse: `lineVmOf`, `lineStatusProvider` (today plus tomorrow,
  minute-inclusive, 1-minute `nowTickProvider`), `shouldShowTerminals`,
  `formatEta` (scheduled `agora`), `Segmented` 56 dp with sliding thumb,
  `GhostLink` 48 dp, `toastControllerProvider` undo pattern on Linhas.

Findings per brief item:

- D1 (map): mostly done. Camera fits live vehicles else city bounds;
  route layer exists but `routePoints` is always empty (no geometry
  committed, see gap below); bounds plus zoom limits plus User-Agent
  plus cache cap plus scrim plus viewer-drawn-only all present.
  Missing: route/stop data (nothing to draw, correctly draws nothing),
  offline `Mapa indisponível offline` chip, map `Semantics` summary
  label, stale dimming beyond `Certainty.stale` (markers carry certainty
  but no 60 s dim style beyond the badge).
- D2 (sheet): peek/half/full snaps exist, but full is 0.92 (keeps a map
  strip, does not hide the map or pause it), tab selection does not
  snap the sheet, system back does not collapse full to peek first.
  Nothing clips at peek (220 dp floor).
- D3 (header): badge plus 2-line title plus star done. Subtitle repeats
  the title (`Centro · IFES / UFES` under `Centro / IFES / UFES`) because
  the header never calls `shouldShowTerminals`. No next-departure chip;
  the status row is certainty plus subtitle only. Star has the 48 dp
  target and same container but generic semantics and no undo snackbar.
- D4 (Agora): hero plus vehicle rows plus next departures exist, but the
  empty state is the large bus illustration (brief says remove) and
  there is no night banner (`Hoje não há mais saídas. Próxima: amanhã`).
  `Ver horários` duplicates the tab control. No per-direction groups
  (times merge origins) and no reserved ETA slot (ETA ships via
  `ArrivalRow` hero, not per vehicle row).
- D5 (share action): no FAB by architecture; the global dock pill plus
  `LineDock` own sharing (same call as home D29 and lines D31). The dock
  fades past peek so it does not cover rows, against the brief ask to
  stay visible at full. No chevron (nothing to inspect). Permission is
  requested only in the share flow, never on open. Locate is the map
  recenter control.
- D6 (Horários): day default is today without holidays, no `hoje` mark,
  empty tabs look selectable, empty state is generic with no
  `Ver dias úteis` jump, origin uses chips with no per-line memory,
  rail layout plus contrast plus tabular plus past dim plus next
  highlight plus auto-scroll are done, but there is no `Primeira ·
  Última` summary and no tomorrow banner. Footnote date is
  `formatDateLabel(now)` (today, wrong) instead of the bundle manifest
  date. `Fontes` goes to `/about` and is readable.
- D7 (contrast): new UI uses `GhostLink` plus theme tokens, not the old
  `TextButton` bug. No systemic dark-on-dark fix needed here; the
  shared `contrast_test.dart` already gates token pairs.
- D8 (segmented): done. `Segmented` is 56 dp, filled thumb, bold label
  via `PontualText.label`, consistent for main tabs and day tabs.
  Origin chips are the odd one out (see D6).
- D9 (service day plus next): `dayTypeFor` plus `nextDeparture`
  (inclusive) plus `resolveNextDeparture` (today else tomorrow) plus
  1-minute tick are shared and tested. No holiday list (UI_SPEC 7.6
  says holidays are manual), no 30 s ticker (same battery call as D29
  and D31), no after-midnight special case beyond the minute rule.
- D10 (polish): sheet fade 160 ms plus rail scroll 200 ms respect
  reduce-motion; header scrolls with the list (does not stay visible);
  titles wrap to 2 lines without touching the star; no snap haptics.

Data gaps (not UI work):

- No route geometry or stop coordinates exist (`data/routes/` absent,
  builder outputs no routes, `LineMap.routePoints` always empty).
  Correctly draws nothing; do not invent lines.
- No per-line `verified_at`; the timetable date must come from the
  bundled manifest (`timetableDateProvider`), not from `now`.
- Municipal holidays plus optional days have no owner list; only the
  national fixed list plus Good Friday could be added client-side.

## 2. What changed

See sections 4 and 5 for the per-item implementation and report.

## 3. Brief conflicts and deviations (D32)

- D2 full-screen sheet skipped: full stays 0.92 with the map behind
  instead of hiding the map and adding a top bar. Hiding the map at
  full would drop the live context the sheet rows act on (tap row to
  focus) and add a second header; the 0.92 snap plus `dockClearance`
  keeps every row reachable without a mode switch.
- D5 FAB skipped: the app uses the global dock pill plus `LineDock`
  per `UI_SPEC.md` 7.1, not an extended FAB (same call as home D29 and
  lines D31). The dock keeps `dockClearance` and never requests
  location on open. The direction step is the existing line chooser
  plus consent flow, not a new `Qual o sentido?` sheet.
- D6 direction memory deferred: origin defaults to the first origin
  with data; per-line persistence needs a new prefs store plus async
  wiring through the timetable tab and stays a follow-up (same reason
  as lines C10).
- D9 holidays plus ticker: no client holiday list and no 30 s ticker.
  Countdowns are minute-granular and a faster tick costs battery on
  the PLAN 3.3 phones (same call as D29 and D31). `Dom/Feriados` stays
  manual per UI_SPEC 7.6; the 2026-10-12 holiday case resolves via the
  user switch, not auto-detection. After-midnight trips stay with the
  minute rule (no data models them otherwise).
- D4 per-direction groups skipped: times merge origins like the lines
  list rule (D-U26); per-direction triplets would triple the rows for
  2-origin lines with no direction signal on live vehicles.
- D1 dark tile filter: the `mapScrim` tint stays; no `ColorFiltered`
  (GPU cost on low-end phones, same call as D-U26 map review).

## 4. Implementation order (one commit per item)

1. `docs(ui): audit line detail screen` (this file).
2. `fix(line): hide duplicate terminals subtitle` (D3).
3. `feat(line): per-line favorite semantics with undo` (D3).
4. `feat(line): compact Agora empty plus night banner` (D4).
5. `feat(timetable): hoje mark plus summary plus tomorrow banner` (D6).
6. `fix(timetable): bundle date in footnote` (D6).
7. `feat(line): header next-departure status row` (D3).
8. Final report update in this file (section 5).

## 5. Final report

### Files touched

- `app/lib/ui/features/line/line_sheet_header.dart`: duplicate
  terminals hidden via `shouldShowTerminals`; star uses per-line
  `favoriteLine`/`unfavoriteLine` semantics plus `Desfazer` toast;
  new `_NextRow` from shared `lineStatusProvider` (tappable countdown,
  `Amanhã`, `Sem mais saídas hoje`, `Sem horários ainda`; hidden while
  live, same live-wins rule as the lines rows; tap opens Horários).
- `app/lib/ui/features/line/line_sheet.dart`: Agora empty is a compact
  card (no bus illustration, no `Ver horários` link); night banner
  (`Sem mais saídas hoje` plus `Amanhã HH:mm`) via `earliestTime`;
  header wired to `lineStatusProvider` plus `timetableDateProvider`.
- `app/lib/ui/features/timetable/timetable_tab.dart`: day tabs mark
  today (`Dias úteis · hoje`); two origins use `Segmented` matching the
  main tabs; `Primeira · Última` summary; tomorrow banner on today only;
  empty day offers `Ver dias úteis` jumping to the first day with data;
  past dim and next highlight apply to today only; footnote shows the
  manifest `timetableDate` passed by the parent (stays testable without
  a `ProviderScope`).
- `app/lib/ui/features/line/line_screen.dart`: map carries
  `Mapa da linha <short>, <live>` semantics; tab switch snaps the sheet
  (Horários to half, Agora to peek, instant with reduce-motion).
- `app/lib/ui/strings/ui_strings.dart`: `todayMark`, `timetableFirst`,
  `timetableLast`, `timetableSeeData`, `mapOfLine` only.
- Tests: `app/test/ui/timetable_tab_test.dart` (hoje label).
- Docs: this file plus `DECISIONS.md` D32.

### Decisions and trade-offs

- 1-minute tick over 30 s (battery, D29/D31 precedent).
- Dock pill over FAB (UI_SPEC 7.1, D29/D31 precedent).
- Times merge origins (D-U26 rule); no per-direction triplets.
- Header next chip hidden while live (live-wins, like lines rows).
- Footnote date via parent param, not a `Consumer` tab (keeps the four
  existing tab tests scope-free).
- Non-today tabs never dim or highlight (their minutes belong to
  another service day).

### What was skipped and why

- Full-screen sheet with hidden map and top bar (D2): keeps live
  context; 0.92 plus clearance reaches every row.
- System-back collapses-full-first: needs sheet-size-aware pop scope;
  follow-up.
- Pinned header while scrolling: needs sheet slivers restructure;
  follow-up.
- Per-line origin memory: needs a new prefs store; follow-up like
  lines C10.
- Holiday auto-detection: manual switch per UI_SPEC 7.6; owner owns
  the municipal list (see below).
- Offline `Mapa indisponível offline` chip: global offline banner
  already covers it; sheet and timetables keep working.
- Stale marker dim style beyond `Certainty.stale`: markers already
  carry certainty plus age; no new paint work.
- Contrast widget test for text buttons (D7): no `TextButton` bug in
  the new UI; token pairs already gated by `contrast_test.dart`.

### Size and performance numbers

Not measured here: per the task instruction no Flutter tooling
(`analyze`, `test`, builds) ran in this session, so APK and web bundle
deltas, frame times and contrast runs must happen on a
Flutter-capable machine before merge (`flutter analyze`,
`flutter test`, 320/360/411 dp plus 390/1280 web, 100 and 200 percent
text scale, dark plus light). Expected delta near zero: no new
dependencies, no images, no blur or shadows, one extra provider watch
per sheet plus text-only rows, lists stay lazy with stable keys.

### Needs owner input

- Municipal holidays plus optional days (Carnival, Corpus Christi):
  no list was added; `Dom/Feriados` stays manual.
- Route geometry and stop coordinates: `data/routes/` is still empty,
  `LineMap.routePoints` stays empty and draws nothing. Commit real
  traces to light up the polyline.
- Default map center if one had to be defined: not needed, the app
  frames `mapBounds` (São Mateus area) and fits live vehicles first.
- Verify on a Flutter machine: `flutter analyze`, `flutter test`
  (timetable hoje, line screen, headers), text-scale and theme passes,
  plus the D2 back-behavior and header-pinning follow-ups above.

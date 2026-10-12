# Lines screen redesign (lines-screen.md brief)

Audit, implementation notes and final report for the Linhas
improvements. The brief is `lines-screen.md` at the repo root. `AGENTS.md`
and `PLAN.md` take precedence over the brief where they conflict; every
conflict is listed in section 3 and recorded in `DECISIONS.md` (D30).

## 1. Audit: current implementation

Widgets involved (`app/lib/ui/features/lines/` plus shared components):

- `lines_screen.dart`: title plus visible-count header (`_Header`),
  filter chips row (`_FilterRow`), lazy `SliverList` of `_LineCard`,
  `dockClearance` bottom padding, empty states per filter.
- Shared: `LineRow`, `LineBadge`, `Chip`, `EmptyState`, `IconBtn`,
  `TripDock`/`LiveDockHost` (global share entry point, no FAB),
  `EtaText`, `LiveDot`, `SectionHeader`, `SearchField` (used on
  Início and Busca, not on Linhas yet).
- Data: `linesVmProvider` (static lines plus `GET /v1/live` counts),
  `staticLinesByKeyProvider` plus `nextDepartureProvider` (today only,
  minute granularity), `TimetableArrivalsSource` (bundled timetables,
  offline first), `currentNowProvider` (1-minute tick),
  `favoritesProvider`, `offlineFlagProvider` (banner only, not watched
  by Linhas), `lineIndexProvider` (search index, used by Busca only).
- Timetable helpers: `timetableTimesOf`, `parseMinutesOf`,
  `domain/schedule.dart` (`dayTypeFor`, `saoMateusTime`, `minutesOf`,
  `nextDeparture` with strict `>`), `formatEta` (scheduled has no
  `agora` branch, past renders `já saiu`), `ArrivalVM.isPast` (exact
  `DateTime` compare, no minute window).
- Home reuse candidates: `joinSubtitle`/`dedupeSubtitleParts`,
  `firstDepartureTomorrow`, `resolveShortcutState`,
  `proximasSectionTitle`, `normalizeText`, `contrastRatio`,
  `bestTextOn`, `lineColorOf` (deterministic hash palette).

Findings per brief item:

- L1 (past next-departure): confirmed. Two defects stack.
  (1) Double timezone shift: `currentNowProvider` already returns
  São Mateus wall clock, but `nextDepartureProvider` calls
  `saoMateusTime` on it again, shifting 3 h early, so afternoon
  rows surface morning times as future. Home does not double
  convert, so the two screens disagree for the same line.
  (2) Day-only scope with strict `>` plus minute truncation:
  a departure at the current minute is skipped instead of `agora`,
  and nothing rolls to tomorrow, so late rows go empty or stale.
  `formatEta` scheduled never returns `agora`, against UI_SPEC 5.1.
- L2 (unsupported lines): confirmed. 21 lines in `data/lines`, only
  4 have schedules (60, 62, 64, 66); 17 are names-only. Rows show
  `Só horários` or terminals with no `Sem horários ainda` state,
  and the header counts filtered rows instead of honest totals.
  Detail handles empty timetables gracefully (`timetableEmpty`
  plus the non-pilot note), so no bottom sheet is needed.
- L3 (badge colors): confirmed. `lineColorOf` hashes keys into a
  10-colour palette with no business meaning; 66, 701 and 60 share
  blue while 62, 23, 13 and 10 are gray. No category module exists.
- L4 (grouping): confirmed. List sorts live first, then favourites,
  then name, pinning favourites to the top without a label.
- L5 (row layout): confirmed. Heavy `SurfaceCard` rows, huge
  right-side `nextEta` plus `Próx.` crowding the title and the star,
  subtitle repeats the title, no tabular status line.
- L6 (live): confirmed. Live dot plus count exist on the row, but
  the chip has no count and no offline empty state.
- L7 (favorites): confirmed. `IconBtn` size 40 (below the 48 dp
  target), no container parity between states, no undo, generic
  semantics without the line number.
- L8 (dock clearance): already resolved by architecture. There is no
  FAB; the global dock pill sits above the bottom nav and the list
  reserves `dockClearance`. No change needed beyond keeping it.
- L9 (search): Busca (`/search`) already covers instant offline
  accent-insensitive search over number, title, stops and tags.
  Inline search on Linhas would duplicate it for 21 rows.
- L10 (polish): confirmed. Chips scroll away instead of staying
  pinned, no counts, no tabular figures guarantee on the row.

## 2. What changed

See sections 4 and 5 for the per-item implementation and report.

## 3. Brief conflicts and deviations (D30)

- L1 asks for a shared 30-second ticker. The screen keeps the
  existing 1-minute `nowTickProvider`: countdowns are
  minute-granular, and a faster tick costs battery on the entry
  level phones in `PLAN.md` 3.3. Same decision as home D29.
  Midnight crossing is covered by the minute tick; resume relies
  on the next tick within one minute.
- L2 bottom sheet skipped: the line detail already renders empty
  timetables plus the non-pilot note without a broken state, so
  rows stay tappable with no sheet. Verified in `line_screen.dart`.
- L7 empty-state wording adjusted: favourites do not feed Home
  shortcuts (shortcuts are a separate store), so the copy drops
  the `e na tela inicial` clause.
- L9 inline search skipped: global Busca already searches the same
  index offline; 21 grouped rows need no second search box. See
  section 5 for the rationale.
- L8 asks for a FAB check: the app uses the global dock pill per
  `UI_SPEC.md` 7.1, not a FAB. Clearance is kept, nothing added.

## 4. Implementation order (one commit per item)

1. `docs(ui): audit Lines screen and past-time root cause` (this file).
2. `fix(lines): never show past next-departure` (L1).
3. `feat(lines): honest timetable states and header counts` (L2).
4. `feat(lines): region color categories` (L3).
5. `feat(lines): group list by category` (L4).
6. `feat(lines): compact row with status line` (L5).
7. `feat(lines): live counts and offline empty states` (L6).
8. `feat(lines): consistent favorites with undo` (L7).
9. `fix(lines): keep dock clearance and pinned chips` (L8, L10).
10. Final report update in this file (section 5).

## 5. Final report

Pending implementation. Will record: root cause and fix, category
mapping table as implemented, `Needs owner assignment` list, files
touched, decisions and trade-offs, what was skipped and why (L9),
size and performance numbers, and assumptions (including line 23).

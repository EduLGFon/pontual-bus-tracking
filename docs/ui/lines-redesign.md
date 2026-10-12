# Lines screen redesign (lines-screen.md brief)

Audit, implementation notes and final report for the Linhas
improvements. The brief is `lines-screen.md` at the repo root. `AGENTS.md`
and `PLAN.md` take precedence over the brief where they conflict; every
conflict is listed in section 3 and recorded in `DECISIONS.md` (D31).

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

## 3. Brief conflicts and deviations (D31)

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

### Root cause and fix (L1)

Two defects stacked to show past times:

1. Double timezone shift. `currentNowProvider` already returns São
   Mateus wall clock, but `nextDepartureProvider` called
   `saoMateusTime` on it again, shifting 3 h early. Afternoon rows
   then surfaced morning times as future. Home never double
   converted, so the screens disagreed.
2. Day-only scope with strict `>` plus minute truncation. A departure
   at the current minute was skipped instead of `agora`, and nothing
   rolled to tomorrow. `formatEta` scheduled had no `agora` branch.

Fix, all in one logical change:

- `domain/schedule.dart`: `nextDeparture` is now inclusive (`>=`,
   earliest match, unsorted-safe) with `nowMinutesOf`,
   `isSameMinute`, `isPastMinute`, `resolveNextDeparture` (today wins,
   else earliest tomorrow, else null) plus `earliestTime` and the
   `NextDeparture` value. Nothing is persisted.
- `ui/util/format_eta.dart`: scheduled at the current minute renders
   `HH:mm` plus `agora` (spec 5.1); past stays `já saiu`.
- `home_sections.dart` `_nextArrival`: minute-inclusive via the shared
   `isPastMinute`, so Home and Linhas agree for the same line.
- `lines_adapter.dart` `lineStatusProvider`: single shared source for
   Linhas, Início live rows and Busca browse rows. Watches the clock,
   so only status texts rebuild on tick, never the list order.
- Tests: `schedule_test.dart` (now-inclusive, tomorrow rollover,
   Fri to Sat and Sat to Sun), `format_eta_test.dart` (scheduled
   `agora`), `line_status_test.dart` (resolver plus subtitle dedupe).

Clock convention: the data is São Mateus local (America/Sao_Paulo,
UTC-3, no DST). `currentNowProvider` is the one wall clock, injected
in tests via override. No timezone package. The 1-minute tick stays
instead of the brief 30 s ticker: countdowns are minute-granular and a
faster tick costs battery on the PLAN 3.3 phones (same call as home
D29). Midnight crossing is covered by the minute tick; resume relies
on the next tick within one minute.

### Category mapping as implemented (L3)

| Category | Badge | Lines (short) |
| --- | --- | --- |
| UFES / IFES (blue) | light 0xFF2563EB, dark 0xFF2B73FF | 60, 62, 64, 66 (explicit) |
| Guriri (yellow, dark text) | light 0xFFEAB308, dark 0xFFFACC15 | 70, 701, 23 (23 is the owner assumption) |
| Aroeira (purple) | light 0xFF7C3AED, dark 0xFFA78BFA | 10, 13 (explicit), 12 (text fallback) |
| Outras (gray) | light 0xFF475569, dark 0xFF687D9A | 20, 21, 30, 40, 41, 50, 51, 71, 81, 90, 120 |

Priority enforced in code: explicit map first, then normalized text
match (`ufes`/`ifes`, then `guriri`, then `aroeira`), else `other`.
`62 Guriri / IFES / UFES` is blue by explicit map despite mentioning
Guriri. Yellow badges resolve dark text via `bestTextOn`; every
category fill passes 4.5:1 in both themes (`contrast_test.dart`).
Green and red are never used. Color is never the only signal: the
category name heads each section and the row semantics carry
`região <label>`. `LineBadge.ofLine` resolves the category itself, so
Home cards, live rows, chooser and gallery share the same fills.

### Needs owner assignment

Gray today, pending region confirmation: 20 Santo Antônio / Cohab, 21
Santo Antônio / Aviação, 30 Liberdade / Morada do Lago, 40 Porto /
Cohab, 41 Santa Tereza / Pedra d'Água, 50 Seac / Alvorada, 51 Bosque,
71 Norte Sul, 81 Paulista, 90 Porto / Pedra d'Água, 120 Ayrton Senna /
Roberto Silvares. Also to confirm: 23 Santo Antônio / Guriri /
Expresso assumed yellow (mentions Guriri); 12 Aroeira / Roberto
Silvares classified Aroeira by text fallback. No regions were
invented: with one confirmed region the palette uses a single purple
plus gray, leaving room for up to six hues later. If a data field for
category would be better than the client map, that is the follow-up.

### Files touched

- `app/lib/domain/schedule.dart`: inclusive next, minute helpers,
   tomorrow resolution.
- `app/lib/domain/line_category.dart` (new): enum, explicit map,
   labels, order, fallback.
- `app/lib/ui/util/format_eta.dart`: scheduled `agora`.
- `app/lib/ui/features/timetable/timetable_data.dart`: `hasTimetable`.
- `app/lib/ui/adapters/lines_adapter.dart`: shared `lineStatusProvider`.
- `app/lib/ui/models/line_status.dart` (new): status kinds, resolver,
   subtitle rule.
- `app/lib/ui/models/line_vm.dart`: untouched (category derived, not stored).
- `app/lib/ui/design/tokens/line_colors.dart`: category fills.
- `app/lib/ui/design/components/line_badge.dart`: category resolution.
- `app/lib/ui/design/components/line_row.dart`: divider rows, status
   line, tabular figures, 48 dp star, per-line semantics.
- `app/lib/ui/features/lines/lines_screen.dart`: honest header, counts,
   grouped list, pinned chips, offline states, favorites undo.
- `app/lib/ui/features/lines/lines_logic.dart` (new): grouping and sort.
- `app/lib/ui/features/home/home_sections.dart`: shared minute rule.
- `app/lib/ui/features/home/home_lists.dart`: live status via shared row.
- `app/lib/ui/features/search/search_screen.dart`: browse rows via shared
   status provider.
- `app/lib/ui/features/trip/line_chooser_sheet.dart`: chooser rows via
   shared status provider.
- `app/lib/ui/design/gallery/gallery_screen.dart`: gallery row status.
- `app/lib/ui/strings/ui_strings.dart`: new Linhas copy only.
- Tests: `schedule_test.dart`, `format_eta_test.dart`,
   `line_category_test.dart` (new), `lines_logic_test.dart` (new),
   `line_status_test.dart` (new), `contrast_test.dart` (category fills),
   `search_lines_test.dart` (counts, grouping, undo),
   `home_screen_test.dart` (live status text).

### Decisions and trade-offs

- 1-minute tick over 30 s (battery, D29 precedent).
- No bottom sheet for unsupported lines: detail already handles empty
   timetables plus the non-pilot note, verified in `line_screen.dart`.
- Favorites copy drops `e na tela inicial`: favorites do not feed Home
   shortcuts (separate store), verified by search.
- `Todas` chip keeps no count (header already shows honest totals);
   `Ao vivo (n)` and `Favoritas (n)` show counts only when nonzero and
   known; offline hides the live count (unknown, not zero).
- Live row count kept as `Ao vivo · N` when N is greater than 1 so Home
   live rows lose no information.
- `Expresso` tag skipped: not trivially derivable without inventing
   parsing rules.
- Headers not sticky (brief allows non-sticky): simpler slivers, no
   extra header math.
- SearchScreen browse and chooser rows now watch the shared status
   provider, so they tick every minute. Lists are tiny (21 rows) and
   rebuilds stay scoped to status texts.

### What was skipped and why (L9)

Inline search on Linhas skipped via the brief escape hatch. Global
Busca (`/search`) already searches the same index offline and
accent-insensitive over number, title, stops, tags and category names;
21 grouped rows need no second search box. A second index, field and
focus flow would add complexity and bundle weight for no new
capability. Revisit if the catalog grows past comfortable scanning.

### Size and performance numbers

Not measured here: per the task instruction no Flutter tooling
(`analyze`, `test`, builds) ran in this session, so APK and web bundle
deltas, frame times and contrast runs must happen on a
Flutter-capable machine before merge (`flutter analyze`,
`flutter test`, 320/360/411 dp plus 390/1280 web, 100 and 200 percent
text scale, dark plus light). Expected delta near zero: no new
dependencies, no images, no blur or shadows, dividers instead of cards,
`SliverList.builder` with stable keys, categories and order computed
once per data change with per-row status providers for the tick.

### Assumptions

- Line 23 is yellow (Guriri). Confirm with the owner.
- São Mateus stays UTC-3 with no DST; holidays are not auto-detected
   (Sunday type covers Sun plus holidays only when the user switches,
   same as the timetable tab).
- Installed apps lag the server: no contract or schema change was made,
   so nothing here needs `min_app_version`.
- `line 23` plus the gray list above are the only classification
   inputs needing owner review.


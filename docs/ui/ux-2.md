# UX 2.0: answer first

Status: implemented 2026-11-11 on Flutter client. UI and copy only. See D104 and UI_SPEC sections 7.1, 7.2, 7.5 and 7.10.

## North star

- Answer "where is my bus" and "when do I leave" before rider finishes thought.
- Label every time as scheduled, live or estimated.
- Shortest path from opening app to departure answer wins.

## First run

- Welcome card -> "Escolher minhas linhas" picker -> favourites -> "Sua próxima saída" hero.
- Picker is local, searchable, multi-select, saves shared favourites store and confirms with "Linhas salvas.".
- No onboarding wall, no coachmark, no permission request. "Só olhar" dismisses card; rider with favourites never sees it.

## Waiting rider

- Início: greeting, "Sua próxima saída" hero, shortcuts, then live or share card.
- When nothing is sharing, live slot becomes actionable share card "Ajude quem está esperando" with "Compartilhar minha viagem" and "Ver horários"; not empty dead end.
- Linhas and Busca are discovery path. Offline keeps bundled timetable and offline banner.

## On-board sharer

- Sharing has explicit entry points: share card on Início, contextual dock on shareable Linha, Ajustes banner.
- Line dock stays bound to its line ("Estou neste ônibus").
- Active trip bar joins layout above navigation and cannot cover content.
- Privacy and consent unchanged: same consent sheet, same opt-in one-shot location, same deletion at trip end.

## Linha screen

- Hero sits above tabs: personal arrival when ready, otherwise vertical `NextBusCard` with ETA first.
- Personal arrival is hero when ready. Compact location prompt appears while location is off.
- Personal card adds walking estimate ("≈N min a pé", straight-line distance at 80 m per minute, minimum 1 minute) and leave-now verdict.
- Header states live count, timetable source or end-of-day state ("Sem mais saídas hoje"), never live-empty sentence; body owns no-live card.
- Peek minimum is 270 dp, so header plus hero ETA fit at 320x568.

## Shell and navigation

- No idle floating dock in shell. Idle screens keep own inline entry points.
- Active trip bar takes layout space and is hidden on Ajustes and under root-level modals or full pages.
- Branch selection keeps `selectionClick` haptic. Bar has no destructive action.

## Linhas and Busca

- Linhas header: title, search icon opening `/search`, honest "N ao vivo" summary hidden offline.
- Browse rows and typed search rows share `LineRow`, `LineStatusLine` and same favourite action and toast.

## Honesty rules

- Scheduled: from timetable, labelled as such.
- Live: current vehicle position, labelled "ao vivo".
- Predicted or estimated: prefixed "≈" and never presented as live.
- Live chip states only live vehicle count; never fabricated live arrival for scheduled value.
- No new network call, location request, ping cadence, consent, auth or location persistence change.

## Accessibility and layout

- Compact 320x568 at 2x text: no overflow; line hero can sit below peek fold and scrolls into view.
- Wide 800x600: 360/400 dp side panel with same hero, readable at normal and 2x text.
- 48 dp minimum targets; semantics on hero, share card, favourite star and leave-now verdict; no meaning by colour alone.

## Verification

- Targeted suites: `home_screen_test`, `home_next_card_test`, `home_next_logic_test`, `line_screen_test`, `personal_arrival_card_test`, `personal_arrival_flow_test`, `leave_now_test`, `line_status_line_test`, `search_lines_test`, `shell_dock_test`.
- Those targeted runs reported green by implementing branches, with `flutter analyze` clean at the time.
- Full `flutter test --concurrency=1` passed on 2026-11-11: 591 tests, 1 skipped; `flutter analyze` clean on integrated tree. Same pass also fixed double São Mateus wall-clock conversion in line sheet and timetable tab, and Início live chip now hugs its content.
- No new dependency: `pubspec.yaml` and `pubspec.lock` unchanged.

## Open items

- Device and field walkthrough of first run, line picker and leave-now verdict.
- Desktop screenshot review completed on 2026-11-11 for Início, Linha, Linhas and Busca at 320, 390 and 800 dp; physical device walkthrough remains.

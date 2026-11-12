# UX 2.0: answer first

Status: implemented 2026-11-11 on the Flutter client. UI and copy only. See `DECISIONS.md` D104 and `UI_SPEC.md` sections 7.1, 7.2, 7.5 and 7.10.

## North star

- Answer "where is my bus" and "when do I leave" before the rider finishes the thought.
- Label every time as scheduled, live or estimated.
- The shortest path from opening the app to a departure answer wins.

## First run

- Welcome card -> "Escolher minhas linhas" picker -> favourites -> "Sua próxima saída" hero.
- The picker is local, searchable, multi-select, saves the shared favourites store and confirms with "Linhas salvas.".
- No onboarding wall, no coachmark, no permission request. "Só olhar" dismisses the card; a rider with favourites never sees it.

## Waiting rider

- Início: greeting, "Sua próxima saída" hero, shortcuts, then live or the share card.
- When nothing is sharing, the live slot becomes the actionable share card "Ajude quem está esperando" with "Compartilhar minha viagem" and "Ver horários"; it is not an empty dead end.
- Linhas and Busca are the discovery path. Offline keeps the bundled timetable and the offline banner.

## On-board sharer

- Sharing has explicit entry points: the share card on Início, the contextual dock on a shareable Linha, and the Ajustes banner.
- The line dock stays bound to its line ("Estou neste ônibus").
- An active trip bar joins the layout above the navigation and cannot cover content.
- Privacy and consent are unchanged: same consent sheet, same opt-in one-shot location, same deletion at trip end.

## Linha screen

- The hero sits above the tabs: personal arrival when ready, otherwise the vertical `NextBusCard` with the ETA first.
- Personal arrival is the hero when ready. The compact location prompt appears while location is off.
- The personal card adds a walking estimate ("≈N min a pé", straight-line distance at 80 m per minute, minimum 1 minute) and a leave-now verdict.
- The header states the live count or the timetable source, never the live-empty sentence; the body owns the no-live card.
- Peek minimum is 270 dp, so the header plus the hero ETA fit at 320x568.

## Shell and navigation

- No idle floating dock in the shell. Idle screens keep their own inline entry points.
- The active trip bar takes layout space and is hidden on Ajustes and under root-level modals or full pages.
- Branch selection keeps its `selectionClick` haptic. The bar has no destructive action.

## Linhas and Busca

- Linhas header: title, search icon opening `/search`, and an honest "N ao vivo" summary, hidden offline.
- Browse rows and typed search rows share `LineRow`, `LineStatusLine` and the same favourite action and toast.

## Honesty rules

- Scheduled: from the timetable, labelled as such.
- Live: a current vehicle position, labelled "ao vivo".
- Predicted or estimated: prefixed "≈" and never presented as live.
- A live chip states only the live vehicle count; it never becomes a fabricated live arrival for a scheduled value.
- No new network call, no new location request, no change to ping cadence, consent, auth or location persistence.

## Accessibility and layout

- Compact 320x568 at 2x text: no overflow; the line hero can sit below the peek fold and scrolls into view.
- Wide 800x600: 360/400 dp side panel with the same hero, readable at normal and 2x text.
- 48 dp minimum targets; semantics on the hero, share card, favourite star and leave-now verdict; no meaning by colour alone.

## Verification

- Targeted suites: `home_screen_test`, `home_next_card_test`, `home_next_logic_test`, `line_screen_test`, `personal_arrival_card_test`, `personal_arrival_flow_test`, `leave_now_test`, `line_status_line_test`, `search_lines_test`, `shell_dock_test`.
- Those targeted runs were reported green by the implementing branches, with `flutter analyze` clean at the time.
- Full `flutter test --concurrency=1` passed on 2026-11-11: 588 tests, 1 skipped; `flutter analyze` clean on the integrated tree.
- No new dependency: `pubspec.yaml` and `pubspec.lock` are unchanged.

## Open items

- Device and field walkthrough of first run, the line picker and the leave-now verdict.

- Spec and screenshot review against `UI_SPEC.md` sections 7.1, 7.2, 7.5 and 7.10.

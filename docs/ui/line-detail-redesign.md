# Line detail screen polish

Status: implemented (see UI_SPEC 7.5, 7.6, DECISIONS.md D32). Full audit, implementation notes and final report removed; only remaining open items are kept.

## Remaining open items

- Full-screen sheet with hidden map and top bar skipped: full stays 0.92 with the map behind to keep live context; 0.92 plus clearance reaches every row.
- System-back collapses-full-first: needs sheet-size-aware pop scope; follow-up.
- Pinned header while scrolling: needs sheet slivers restructure; follow-up.
- Per-line origin memory: needs a new prefs store; follow-up.
- Holiday auto-detection: manual switch per UI_SPEC 7.6; owner owns the municipal list.
- Offline `Mapa indisponível offline` chip: global offline banner already covers it; sheet and timetables keep working.
- Stale marker dim style beyond `Certainty.stale`: markers already carry certainty plus age; no new paint work.
- Route geometry and stop coordinates: `data/routes/` still empty, `LineMap.routePoints` stays empty and draws nothing. Commit real traces to light up the polyline.
- Municipal holidays plus optional days (Carnival, Corpus Christi): no list added; `Dom/Feriados` stays manual.
- Verification on a Flutter-capable machine: `flutter analyze`, `flutter test` (timetable hoje, line screen, headers), text-scale and theme passes, plus the D2 back-behavior and header-pinning follow-ups.

## Decisions retained

- 1-minute tick over 30 s (battery).
- Dock pill over FAB (UI_SPEC 7.1).
- Times merge origins (D-U26 rule); no per-direction triplets.
- Header next chip hidden while live (live-wins, like lines rows).
- Footnote date via parent param, not a `Consumer` tab.
- Non-today tabs never dim or highlight.
- `mapScrim` tint stays; no `ColorFiltered` (GPU cost).
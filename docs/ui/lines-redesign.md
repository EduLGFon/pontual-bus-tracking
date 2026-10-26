# Lines screen redesign

Status: implemented (see UI_SPEC 7.4, DECISIONS.md D31). Full audit, implementation notes and final report removed; only remaining open items are kept.

## Remaining open items

- Owner assignment of region categories for gray lines: 20 Santo Antônio / Cohab, 21 Santo Antônio / Aviação, 30 Liberdade / Morada do Lago, 40 Porto / Cohab, 41 Santa Tereza / Pedra d'Água, 50 Seac / Alvorada, 51 Bosque, 71 Norte Sul, 81 Paulista, 90 Porto / Pedra d'Água, 120 Ayrton Senna / Roberto Silvares. Also confirm 23 Santo Antônio / Guriri / Expresso as yellow and 12 Aroeira / Roberto Silvares as Aroeira by text fallback.
- Verification on a Flutter-capable machine: `flutter analyze`, `flutter test`, 320/360/411 dp plus 390/1280 web, 100 and 200 % text scale, dark and light themes.

## Decisions retained

- 1-minute tick over 30 s (battery).
- No bottom sheet for unsupported lines: detail already handles empty timetables plus the non-pilot note.
- Favorites copy drops `e na tela inicial`: favorites do not feed Home shortcuts (separate store).
- Inline search on Linhas skipped: global Busca (`/search`) already searches the same index offline; 21 grouped rows need no second search box. Revisit if the catalog grows past comfortable scanning.
- Dock pill over FAB (UI_SPEC 7.1); clearance kept.
- `Todas` chip keeps no count (header shows honest totals); `Ao vivo (n)` and `Favoritas (n)` show counts only when nonzero and known; offline hides the live count.
- `Expresso` tag skipped: not trivially derivable without inventing parsing rules.
- Headers not sticky.
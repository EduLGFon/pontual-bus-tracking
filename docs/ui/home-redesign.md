# Home screen redesign

Status: implemented (see UI_SPEC 7.2, DECISIONS.md D29). Full audit, implementation notes and final report removed; only remaining open items are kept.

## Remaining open items

- Cache-age line (`Atualizado há X min`) skipped: needs cache-age plumbing through `StaticDataRepository`; documented for a follow-up.
- Owner review of region/category inputs where applicable (see lines-redesign.md).
- Verification on a Flutter-capable machine: `flutter analyze`, `flutter test` (home logic and screen), widget checks at 320/360/411 dp widths, 200 % text scale, dark and light themes.

## Decisions retained

- Global `TripDock` pill used instead of an extended FAB (UI_SPEC 7.1); dock clearance kept.
- Cards stay at `Sizes.shortcutWidth` (156 dp) token (UI_SPEC); 2-line label plus direction line fixes indistinguishability.
- 1-minute `nowTickProvider` kept instead of a 30 s ticker (battery).
- Non-breaking spaces not applied to `formatEta` because unit tests pin regular spaces.
- Line colours already implemented via `LineBadge` plus deterministic palette in `line_colors.dart`.
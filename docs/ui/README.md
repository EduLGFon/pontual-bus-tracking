# UI documentation index

Documents for the new UI of Pontual. The specification lives in
`UI_SPEC.md`; the implementation must satisfy it and record every
deviation in `DECISIONS.md`.

| Document | Purpose |
|---|---|
| `UI_SPEC.md` | The construction guide: tokens, components, screens, platform rules, performance and accessibility budgets. |
| `AUDIT.md` | U01 repository audit: what existed, what is reused, what was missing, and the measurement plan. |
| `VERIFY-NOTES.md` | Package API and policy verification for the pinned Flutter and package versions, with sources. |
| `a11y-script.md` | Manual accessibility run-through used before every release. |
| `DECISIONS.md` | (repo root) ADRs and deviations, append-only. |

## Where the code lives

```
app/lib/ui/
  design/tokens/     colours, text, spacing, motion, line colours
  design/theme/      ThemeData plus the context token accessors
  design/components/  the component catalog of UI_SPEC section 5
  design/icons/       custom-painted domain icons (bus, live waves, spark, route, terminal)
  design/gallery/     debug-only component gallery, stripped from release
  shell/              adaptive shell, navigation, dock host, toast, offline bridge
  features/           home, search, lines, line, timetable, trip, settings, system
  adapters/           view-model providers reading the existing data layer
  models/             certainty, line, arrival, vehicle, shortcut, trip, features
  util/               pure helpers: ETA formatting, search index, contrast, platform
  strings/            the pt-BR copy deck
```

## Rules the implementation follows

1. UI code reads data only through `adapters/`. No screen imports
   `data/` providers directly.
2. No widget holds a raw colour, font size, radius or duration: everything
   comes from `context.colors` and `context.text`.
3. No screen invents its own certainty style: `CertaintyBadge` and
   `certainty_style.dart` are the single source of truth.
4. User-visible strings come from `ui/strings/ui_strings.dart`.
5. A disabled feature renders nothing; the flag list is in
   `models/features.dart`.
6. The legacy screens are gone: the cutover deleted every screen in
   `lib/features/`, the `lib/app/` scaffolding (`router.dart`, `theme.dart`,
   `strings_pt.dart`) and the `NEW_UI` flag. What stays is logic the new UI
   calls through its adapters: the trip controller and share flow, the tile
   source, the privacy actions, the consent and permission sheets, and the
   provider wiring. `main.dart` boots the new UI directly.

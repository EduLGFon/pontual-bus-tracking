# UI documentation index

Documents for the Pontual UI. The specification lives in `UI_SPEC.md`; deviations are recorded in the repo-root `DECISIONS.md` (append-only).

| Document | Purpose |
|---|---|
| `UI_SPEC.md` | Construction guide: tokens, components, screens, platform rules, performance and accessibility budgets. |
| `AUDIT.md` | U01 repository audit: what existed, what is reused, what was missing, measurement plan. |
| `VERIFY-NOTES.md` | Package API and policy verification for pinned Flutter/package versions, with sources. |
| `PERF.md` | Performance baseline and budgets (U21). |
| `a11y-script.md` | Manual accessibility run-through used before every release. |
| `home-redesign.md`, `line-detail-redesign.md`, `lines-redesign.md`, `settings-redesign.md`, `sharing-screen-redesign.md` | Redesign brief audits and reports. All implemented; see each file for remaining open items. |
| `DECISIONS.md` (repo root) | ADRs and deviations, append-only. |

## Where the code lives

```
app/lib/ui/
  design/tokens/     colours, text, spacing, motion, line colours
  design/theme/      ThemeData plus context token accessors
  design/components/  component catalog (UI_SPEC 5)
  design/icons/       custom-painted domain icons
  design/gallery/     debug-only component gallery, stripped from release
  shell/              adaptive shell, navigation, dock host, toast, offline bridge
  features/           home, search, lines, line, timetable, trip, settings, system
  adapters/           view-model providers reading the existing data layer
  models/             certainty, line, arrival, vehicle, shortcut, trip, features
  util/               pure helpers: ETA formatting, search index, contrast, platform
  strings/            the pt-BR copy deck (ui_strings.dart)
```

## Rules the implementation follows

1. UI code reads data only through `adapters/`. No screen imports `data/` providers directly.
2. No widget holds a raw colour, font size, radius or duration: everything comes from `context.colors` and `context.text`.
3. No screen invents its own certainty style: `CertaintyBadge` and `certainty_style.dart` are the single source of truth.
4. User-visible strings come from `ui/strings/ui_strings.dart`.
5. A disabled feature renders nothing; the flag list is in `models/features.dart`.
6. Cutover complete: the legacy `lib/features/`, `lib/app/` scaffolding and the `NEW_UI` flag are removed. `main.dart` boots the new UI directly. Logic the new UI calls through adapters remains (trip controller, tile source, privacy actions, consent/permission sheets, provider wiring).
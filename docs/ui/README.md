# UI documentation index

Spec: `UI_SPEC.md`; deviations: root `DECISIONS.md` (append-only).

| Document | Purpose |
|---|---|
| `UI_SPEC.md` | Construction guide: tokens, components, screens, platform rules, perf/a11y budgets. |
| `AUDIT.md` | U01 audit: existing, reused, missing, measurement plan. |
| `VERIFY-NOTES.md` | Package API/policy verification for pinned versions. |
| `PERF.md` | Performance baseline/budgets (U21). |
| `a11y-script.md` | Manual a11y run-through before each release. |
| `*-redesign.md` | Redesign audits/reports; implemented; open items remain. |
| `personal-arrival.md` | Personal arrival on line screen: opt-in one-shot foreground fix, nearest learned stop snap, ETA via existing endpoint, privacy/honesty rules (D96). |
| `ux-2.md` | UX 2.0 answer-first: first-run picker, next-departure hero, share card, line hero/leave-now, lines/search status, shell active trip bar (D104). |
| root `DECISIONS.md` | ADRs/deviations, append-only. |

## Where the code lives

```
app/lib/ui/
  design/tokens/     colours, text, spacing, motion, line colours
  design/theme/      ThemeData plus context token accessors
  design/components/ component catalog (UI_SPEC 5)
  design/icons/      custom-painted domain icons
  design/gallery/    debug-only component gallery, stripped from release
  shell/             adaptive shell, navigation, dock host, toast, offline bridge
  features/          home, search, lines, line, timetable, trip, settings, system
  adapters/          view-model providers reading the existing data layer
  models/            certainty, line, arrival, vehicle, shortcut, trip, features
  util/              pure helpers: ETA formatting, search index, contrast, platform
  strings/           pt-BR copy deck (ui_strings.dart)
```

## Rules the implementation follows

1. UI reads data only through `adapters/`; no screen imports `data/` providers directly.
2. No raw colour, font size, radius or duration in widgets; use `context.colors` and `context.text`.
3. No screen invents certainty style; `CertaintyBadge` and `certainty_style.dart` are the single source.
4. User-visible strings come from `ui/strings/ui_strings.dart`.
5. A disabled feature renders nothing; flag list is in `models/features.dart`.
6. Cutover complete: legacy `lib/features/`, `lib/app/` scaffolding and `NEW_UI` flag removed; `main.dart` boots new UI directly. Logic called through adapters remains (trip controller, tile source, privacy actions, consent/permission sheets, provider wiring).

# UI_SPEC.md - Pontual: new UI construction guide (Flutter, Android + Web)

> Version 1.0 - 2026-10-14. Audience: the AI model (and human reviewer) that
> will build the new UI of **Pontual** (repo `pontual-bus-tracking`) in Flutter
> for **Android and Web**. Scope: **presentation layer only**. Backend, API
> client, auth/token handling, trip tracking, static data and security keep
> working exactly as they do today. Place this file at `docs/ui/UI_SPEC.md`. It
> extends `AGENTS.md` and `PLAN.md`; where they conflict, `AGENTS.md` and the
> security/LGPD rules of `PLAN.md` win.

## Table of contents

0. How to use this document
1. North star and design principles
2. Hard constraints (performance, privacy, accessibility)
3. The Certainty system (the signature idea)
4. Design tokens
5. Component catalog
6. UI architecture (folders, view-models, extension seams)
7. Screens (wireframes, behaviour, states, copy)
8. Platform differences: Android vs Web
9. Motion and micro-interactions
10. Loading, empty, error and offline patterns
11. Performance engineering rules (Flutter specific)
12. Accessibility spec
13. Future features: how the UI receives them
14. Copy deck (pt-BR)
15. Brand assets
16. Implementation plan (tasks U01 to U26)
17. QA, acceptance and measurement
18. Reading list and references

---

## 0. How to use this document

### 0.1 Rules for the implementing model

1. **Inspect before modifying.** Task U01 is a repository audit. Do not assume
   file names, providers, packages or models: this document names concepts, the
   repo decides the names. Map every concept here to what exists
   (`docs/ui/AUDIT.md`).
2. **Presentation layer only.** Do not change the API client, authentication,
   consent recording, tracking/ping logic, static-data loading, or backend
   contracts. If the UI needs data in another shape, add a thin **adapter**
   (view-model provider) in the UI layer. Never edit domain logic to suit a
   widget.
3. **Strangler migration.** Build the new UI in a new folder (`lib/ui/`) next to
   the old one. Switch screens one by one behind a compile-time flag
   (`--dart-define=NEW_UI=true`) until parity, then cut over and delete the old
   UI (task U24). The app must build, run and pass tests after every task.
4. **One change per task** (section 16). Small commits, Conventional Commits. Do
   not start the next task until the acceptance criteria pass.
5. **Measure before and after.** Record baseline metrics in U01 and compare in
   U21 (section 17). Performance regressions beyond budget block the cutover.
6. **Do not invent facts.** Items marked VERIFY (package APIs, store policies,
   browser behaviour, tile-provider terms) must be checked against official
   documentation for the **Flutter and package versions pinned in this repo**
   and noted in `DECISIONS.md`.
7. **No new dependencies without an ADR** (section 2.2). The default answer is
   "write 40 lines of Dart instead".
8. **Language:** code, comments, docs, commits in English. All user-visible
   strings in pt-BR, kept in the project's existing strings file (never
   hard-coded in widgets).
9. **No em dashes** in anything you write (conversation, comments, docs,
   commits, UI strings). Use hyphens.
10. If something here is wrong, impossible, or conflicts with the repo, say so,
    propose the fix, and record it in `DECISIONS.md`.

### 0.2 Recommended model/effort per task

Each task in section 16 has an **M/E** column (S5.5 = Claude Sonnet 5.5, O5.5 =
Claude Opus 5.5, H4.5 = Claude Haiku 4.5; effort L/M/H). Use stronger settings
for the trip flow (permissions per platform), the map layer and the performance
audit.

### 0.3 What "done" looks like

The owner opens the app (Android) or the website (GitHub Pages) and sees a calm,
confident, premium interface that paints instantly, never janks, makes the next
bus obvious in under two seconds, and is honest about what is live, predicted or
just a timetable. All budgets in section 2.1 are met.

---

## 1. North star and design principles

**North star:** _"Where is my bus, and when do I leave?" answered before the
user finishes the thought._

**Design feeling:** quiet luxury meets transit clarity. Big confident numbers,
generous whitespace, one deep brand colour with one vivid "signal" colour,
hairline borders instead of heavy shadows, almost no decoration that costs GPU.
Beauty comes from **typography, spacing, colour discipline, motion timing and
copy**, which are all free in CPU terms.

### 1.1 Principles (apply in this order when they conflict)

1. **Speed is a feature.** First paint from cache, interactions under 100 ms,
   transitions <= 200 ms, no spinner for cached data. Perceived speed counts as
   much as measured speed.
2. **Honesty about time.** A live position, a prediction and a timetable are
   different promises. The UI always shows which one the user is looking at
   (section 3). A rider who misses a bus because a schedule looked live will not
   forgive the app.
3. **Directness.** One primary action per screen. The next bus is the hero. No
   feature tours, no required onboarding, no dead ends.
4. **Don't make me think** (Krug): labels say what happens, icons never stand
   alone for important actions, the same thing always looks and behaves the
   same.
5. **Glanceable first, detail on demand.** Progressive disclosure: row -> sheet
   -> detail.
6. **Thumb-first.** Primary controls in the lower half of the screen; sheets and
   a bottom dock instead of top-heavy navigation.
7. **Calm technology.** Motion only where it explains state change. Nothing
   animates when nothing changes. Respect reduced motion.
8. **Everything flexible.** Lines, names, counts, terminals, colours and
   features will change. No hard-coded catalogs, no layouts that only fit
   today's data.
9. **Accessible by default.** Screen readers, 200 % text, keyboard, colour-blind
   safe, 48 dp targets.
10. **Privacy visible.** Say plainly what is shared and when it stops. Trust is
    part of the premium feel.
11. **Light by construction.** Every visual idea is checked against section 11
    before it is built. If it needs blur, offscreen layers, big images or heavy
    packages, find another way.

### 1.2 Research basis (applied throughout)

- **Books:** _Don't Make Me Think, Revisited_ (Krug), _The Design of Everyday
  Things_ (Norman), _Refactoring UI_ (Wathan, Schoger), _Laws of UX_
  (Yablonski), _Universal Principles of Design_ (Lidwell et al.), _100 Things
  Every Designer Needs to Know About People_ (Weinschenk), _Mobile First_
  (Wroblewski), _Designing Interfaces_ (Tidwell), _Microinteractions_ (Saffer),
  _Inclusive Design Patterns_ (Pickering), _Atomic Design_ (Frost). Full list in
  section 18.
- **Heuristics:** Nielsen's 10 usability heuristics; WCAG 2.2 AA; Material 3 and
  Apple HIG for platform behaviour (used as references, **not** copied as a
  look).
- **Laws of UX used on purpose:** Hick (few choices per screen), Fitts (large,
  close thumb targets, dock at the bottom), Jakob (familiar patterns for sheets,
  tabs, search), Miller (chunk lists, <= 7 items per group before a "see all"),
  Doherty threshold (respond < 400 ms, ideally instant), Peak-End (make
  start-of-trip and end-of-trip moments delightful), Von Restorff (one standout
  element per screen: the ETA or the primary button), Aesthetic-Usability effect
  (beautiful reads as easier).
- **Transit research:** real-time information reduces _perceived_ wait time and
  even actual wait time for riders, so the ETA must be the star. Leading transit
  apps label real-time vs scheduled explicitly (pulsing "waves" for real-time,
  greyed time for schedule, a dot for live). Stale data must say how old it is.
  Screen-reader users should hear arrival times in natural language.
- **Flutter performance guidance:** avoid extra opacity layers and `saveLayer`,
  prefer `const`, use `RepaintBoundary` only on hot repainting subtrees after
  profiling, avoid intrinsics, keep builds small, measure with DevTools in
  profile mode.

---

## 2. Hard constraints

### 2.1 Budgets (compare with the U01 baseline; the stricter of the two wins)

| Metric                              | Budget                                                                                          |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| Time to first frame (release, cold) | no worse than baseline +10 %; web shows the HTML splash within the first paint                  |
| Android size delta                  | <= +400 KB over baseline (fonts + code)                                                         |
| Web initial transfer delta          | <= +120 KB over baseline; map code is a **deferred** chunk                                      |
| Frame time                          | p95 build < 8 ms and raster < 8 ms on a mid-range phone; no frame > 32 ms in transitions        |
| Map pan/zoom                        | >= 55 fps (>= 90 % of frames in budget) on the low-end reference phone                          |
| Memory                              | <= baseline +15 MB on the line screen                                                           |
| Idle CPU on Home                    | ~0 %: **no ticker, timer or animation runs when nothing visible changes**                       |
| Interaction latency                 | tap to visual feedback < 100 ms; navigation to a cached screen paints in the first frame        |
| Data                                | no new network calls from the UI layer; the UI never polls (data layer already handles streams) |

### 2.2 Dependencies

- **Allowed (already in the project, verify in U01):** `flutter_riverpod`,
  `go_router`, `flutter_map`, `latlong2`, `geolocator`, `shared_preferences`,
  `url_launcher`, and the other packages the project already uses.
- **Forbidden:** `google_fonts` (runtime font download, privacy, weight),
  `flutter_svg`, `lottie`, `rive`, `shimmer`, `cached_network_image`, any
  animation or UI-kit package, any blur/glass package, any chart package,
  `permission_handler` unless already present, analytics/telemetry/Firebase
  (privacy rule), icon packs with large fonts.
- **Dev-only allowed:** `flutter_launcher_icons`, a font subsetter (`pyftsubset`
  from fonttools, run outside Flutter).
- Anything else needs an ADR: size impact, maintenance health, licence,
  permissions.

### 2.3 Privacy and security (unchanged, and visible in the UI)

- Location is shared **only after explicit consent** and only during a trip. The
  UI never shows other riders, only vehicles.
- Never log or display coordinates, tokens or ids in debug overlays that could
  ship. Debug-only screens are compiled out of release (`kDebugMode` guard plus
  tree-shaking).
- The UI must make consent, what is shared, and how to stop obvious (section
  7.7).
- No third-party SDKs, no analytics, no remote fonts or images. External links
  open in the system browser.

### 2.4 Accessibility minimums

WCAG 2.2 AA contrast (4.5:1 text, 3:1 graphics), 48 dp touch targets (never
below 44), text scale to 200 % without clipping, TalkBack and VoiceOver labels
in natural pt-BR, full keyboard operation on web, reduced-motion support, no
information by colour alone. Details in section 12.

---

## 3. The Certainty system (the signature idea)

Every time, position or estimate in the UI belongs to exactly one **Certainty**.
This single concept makes the UI honest today and receives ETA, prediction and
history tomorrow without redesign.

```dart
enum Certainty { live, predicted, scheduled, stale }
```

| Certainty   | Meaning                                                           | Colour role               | Shape / icon                                                    | Text rule                                            | Example                 |
| ----------- | ----------------------------------------------------------------- | ------------------------- | --------------------------------------------------------------- | ---------------------------------------------------- | ----------------------- |
| `live`      | measured by a rider's phone in the last ~45 s                     | `live` (green)            | solid filled dot with two emitting "waves" icon (like a signal) | plain number, label "Ao vivo"                        | `4 min` + wave icon     |
| `predicted` | estimated from recent data and driver/route pace (future feature) | `predicted` (indigo)      | **dashed** outline, hollow/ghost fill, small "spark" icon       | **always prefixed with `~`** and labelled "Previsão" | `~4 min` + dashed badge |
| `scheduled` | from the static timetable only                                    | `scheduled` (neutral ink) | clock icon, no colour emphasis                                  | clock time in grey: `14:35`, countdown secondary     | `14:35` `em 12 min`     |
| `stale`     | was live, no update for > 45 s                                    | `warning` (amber)         | faded, half-ring icon                                           | "Última posição há N min"                            | `há 3 min`              |

Rules:

1. **Never show a predicted or scheduled value styled as live.** Never mix two
   certainties in one number.
2. If both a live and a predicted/scheduled value exist for the same thing, show
   the live one as the hero and the other as secondary text.
3. **Colour is never the only signal:** shape (solid / dashed / hollow), icon,
   prefix (`~`) and the word are all present. This also covers colour-blind
   users.
4. Certainty is a **single source of truth** in one widget: `CertaintyBadge`
   (section 5) and one style table (`CertaintyStyle`). No screen invents its
   own.
5. When a live fix arrives for something shown as predicted, animate the change
   in 200 ms (ghost snaps to solid) so the user sees the promise become fact.
6. Every non-live certainty has an info affordance ("Como calculamos isso?")
   opening a short bottom sheet (copy in section 14).

```dart
@immutable
class CertaintyStyle {
  const CertaintyStyle({required this.label, required this.icon, required this.dashed, required this.prefix});
  final String label;       // from strings file: 'Ao vivo', 'Previsão', 'Horário', 'Sem sinal'
  final IconData icon;      // custom-painted or tree-shaken Material icon
  final bool dashed;        // outline style for markers/badges
  final String prefix;      // '~' for predicted, '' otherwise
}
// Colours come from PontualColors (section 4.1), never hard-coded here.
```

---

## 4. Design tokens

All tokens live in `lib/ui/design/tokens/` and are consumed through `Theme`
extensions. **No widget may contain a raw colour, font size, radius or
duration.**

### 4.1 Colour (starting values; U04 must verify contrast with a test and adjust)

Brand idea: **deep pine** (calm, premium, ink-like) plus a vivid mint **signal**
used only for live things and the primary action in dark mode.

| Token                     | Light                 | Dark                  | Use                                                        |
| ------------------------- | --------------------- | --------------------- | ---------------------------------------------------------- |
| `bg`                      | `#F6F5F1`             | `#0A1110`             | screen background (warm paper / near-black, OLED friendly) |
| `surface`                 | `#FFFFFF`             | `#121B19`             | cards, sheets, rows                                        |
| `surfaceSunken`           | `#EDECE6`             | `#0E1614`             | inputs, wells, chips background                            |
| `surfaceRaised`           | `#FFFFFF`             | `#1A2623`             | dock, dialogs                                              |
| `line`                    | `#E3E1D9`             | `#26332F`             | hairline borders, dividers                                 |
| `ink`                     | `#0F1B18`             | `#EAF2EE`             | primary text                                               |
| `inkMuted`                | `#44544F`             | `#A9B8B2`             | secondary text                                             |
| `inkSubtle`               | `#5F6F6A`             | `#8A9A94`             | tertiary text (still >= 4.5:1)                             |
| `primary`                 | `#0B3D36`             | `#62E8B0`             | primary buttons, key accents                               |
| `onPrimary`               | `#FFFFFF`             | `#07140F`             | text on primary                                            |
| `live` (graphics)         | `#17B26A`             | `#3DDC97`             | live dots, markers, rings                                  |
| `liveText`                | `#087443`             | `#6EE7B7`             | live text                                                  |
| `predicted` (graphics)    | `#5B4BDB`             | `#A9A0FF`             | predicted rings, dashed lines                              |
| `predictedText`           | `#4A3BC4`             | `#C4BEFF`             | predicted text                                             |
| `scheduled`               | `#5F6F6A`             | `#8A9A94`             | timetable-only text/icons                                  |
| `warning` / `warningText` | `#D97706` / `#B45309` | `#FBBF24` / `#FBBF24` | stale, notices                                             |
| `danger` / `dangerText`   | `#C2362B` / `#B42318` | `#FF8A80` / `#FF8A80` | destructive actions, errors                                |
| `scrim`                   | `#0F1B18` @ 40 %      | `#000000` @ 60 %      | modal scrims                                               |
| `mapScrim`                | `#F6F5F1` @ 18 %      | `#0A1110` @ 35 %      | subtle tint over map tiles (section 7.5)                   |

Rules: text on `bg`/`surface` must be >= 4.5:1; graphics >= 3:1; `primary` on
`bg` >= 3:1. Add a Dart test (`contrast_test.dart`) that computes WCAG contrast
for every foreground/background pair used and fails below the thresholds.
**Adjust the hex values until the test passes and record final values here.**

**Line colours.** Colour is deterministic per line so it stays stable when lines
change: `LineColors.of(lineKey)` hashes the stable line id/code into a curated
**10-colour palette** (starting set: `#2563EB`, `#0284C7`, `#0891B2`, `#0F766E`,
`#C026D3`, `#DB2777`, `#EA580C`, `#92400E`, `#475569`, `#9F1239`). The palette
**excludes pure green (reserved for live) and indigo/violet (reserved for
predicted)**. For every colour compute a legible badge text colour (white or
near-black) and, if neither reaches 4.5:1, darken/lighten the fill until it
does; provide separate light and dark variants. If the line data later gets an
optional `color` field, it overrides the hash (validated for contrast).

### 4.2 Typography

- **One typeface, bundled, subsetted.** Candidates in order: **Manrope**, **Plus
  Jakarta Sans**, **Inter** (all SIL OFL). Pick the first that has: a variable
  weight axis (or static 400/500/600/700/800), **tabular figures** (`tnum`) so
  countdowns do not jitter, full Portuguese glyph coverage. Subset to Latin +
  Latin-1 supplement + punctuation + arrows/symbols actually used; target **<=
  70 KB total** (WOFF2 is not used by Flutter; use TTF/OTF, subsetted). Register
  in `pubspec.yaml`; never use `google_fonts`; no fallback download.
- Always enable tabular figures for numbers that change:
  `fontFeatures: [FontFeature.tabularFigures()]`.
- Sizes are in logical pixels and scale with the user's text scale (never fix
  with `textScaler: noScaling`). Minimum 12.

| Style        | Size / line height | Weight | Letter spacing | Use                              |
| ------------ | ------------------ | ------ | -------------- | -------------------------------- |
| `etaHero`    | 56 / 56            | 800    | -1.5           | the big minutes on cards/sheets  |
| `etaLarge`   | 34 / 36            | 800    | -0.8           | ETA in rows                      |
| `display`    | 32 / 38            | 700    | -0.6           | screen titles on Home (greeting) |
| `title`      | 22 / 28            | 700    | -0.3           | screen/section titles            |
| `headline`   | 18 / 24            | 600    | -0.1           | card titles, line names          |
| `body`       | 16 / 24            | 400    | 0              | main text                        |
| `bodyStrong` | 16 / 24            | 600    | 0              | emphasised body                  |
| `label`      | 14 / 20            | 600    | 0.1            | buttons, chips, tabs             |
| `caption`    | 12 / 16            | 500    | 0.2            | metadata, badges, units          |

Rules: max two weights per screen region; long names wrap to two lines then
ellipsis; never uppercase whole sentences; numbers right-aligned in tables;
Portuguese copy is typically 20-30 % longer than English: leave room.

### 4.3 Spacing, size, shape

- **4 pt grid.** Scale: `4, 8, 12, 16, 20, 24, 32, 48`. Screen margin: 20
  (compact), 24 (medium), 32 (expanded).
- Radii: `8` (small chips), `12` (inputs, small cards), `16` (cards, rows), `24`
  (top of sheets), `999` (pills, badges).
- Minimum touch target 48x48 dp (expand hit area with padding, not by enlarging
  visuals).
- Icons 20 and 24 dp, stroke-like and rounded; one family only.
- **Depth without shadow:** tonal layering (`bg` < `surface` < `surfaceRaised`)
  plus a 1 px `line` border. Shadows are **forbidden in lists and cards**.
  Allowed only: the bottom dock and the bottom sheet top edge, one soft shadow
  (`blur 16, offset (0,4), 10-14 % alpha`), each inside a `RepaintBoundary`. No
  gradients except one optional very subtle linear gradient on the hero card.

### 4.4 Motion tokens

| Token                                                                                                                                                  | Value                                                                                      | Use                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `instant`                                                                                                                                              | 80 ms                                                                                      | pressed states, reduced-motion fades                               |
| `fast`                                                                                                                                                 | 140 ms                                                                                     | chip/segment changes, ETA digit change                             |
| `base`                                                                                                                                                 | 200 ms                                                                                     | page transitions, snap to certainty change                         |
| `slow`                                                                                                                                                 | 320 ms                                                                                     | sheet settle (spring handled by the framework), first-load reveals |
| curves                                                                                                                                                 | `Curves.easeOutCubic` (enter), `Curves.easeInCubic` (exit), `Curves.easeInOutCubic` (move) |                                                                    |
| Reduced motion (`MediaQuery.disableAnimations` or the in-app setting): durations -> `instant`, no pulses, no marker interpolation (jump), no parallax. |                                                                                            |                                                                    |

### 4.5 Iconography

Use tree-shaken built-in `Icons.*_rounded` for generic icons. Domain icons are
**custom-painted** (`CustomPainter` + `Path`, about 10-20 lines each): `BusIcon`
(front view), `LiveWavesIcon`, `PredictionSparkIcon`, `ClockIcon` (or built-in),
`RouteIcon`, `TerminalIcon`. Keep one visual weight (rounded caps, 1.75 stroke
at 24 dp). Source drawings in `design/icons/` (SVG) for reference.

### 4.6 Haptics (Android; no-op on web)

`HapticFeedback.selectionClick` on segment/tab/chip changes and sheet snap;
`lightImpact` on primary button press and end of trip; `mediumImpact` when a
trip starts successfully. Always behind a tiny `Haptics` wrapper that respects a
settings toggle and ignores web.

### 4.7 Token code shape (sketch; adapt names to the repo)

```dart
@immutable
class PontualColors extends ThemeExtension<PontualColors> {
  const PontualColors({required this.bg, required this.surface, required this.surfaceSunken, required this.surfaceRaised,
    required this.line, required this.ink, required this.inkMuted, required this.inkSubtle, required this.primary,
    required this.onPrimary, required this.live, required this.liveText, required this.predicted, required this.predictedText,
    required this.scheduled, required this.warning, required this.warningText, required this.danger, required this.dangerText,
    required this.scrim, required this.mapScrim});
  final Color bg, surface, surfaceSunken, surfaceRaised, line, ink, inkMuted, inkSubtle, primary, onPrimary,
      live, liveText, predicted, predictedText, scheduled, warning, warningText, danger, dangerText, scrim, mapScrim;
  static const light = PontualColors(/* values from 4.1 */);
  static const dark = PontualColors(/* values from 4.1 */);
  @override PontualColors copyWith(/* ... */) => /* ... */;
  @override PontualColors lerp(PontualColors? other, double t) => /* ThemeExtension lerp */;
}
extension PontualContext on BuildContext {
  PontualColors get colors => Theme.of(this).extension<PontualColors>()!;
  PontualText get text => /* similar extension for the text styles in 4.2 */;
}
```

Build `ThemeData` once per brightness (`useMaterial3: true` as a base only), set
`splashFactory: NoSplash.splashFactory`, transparent system overlays, and own
the look through the extensions. Do not rely on Material defaults for anything
visible.

---

## 5. Component catalog

Build every component in `lib/ui/design/components/`, each with: a `const`
constructor, no business logic, all states, semantics, and a widget test. A
debug-only **gallery route** (`/_gallery`, compiled out of release) shows every
component in light/dark and at text scale 1.0 and 2.0 for visual QA.

**Interaction base (`Pressable`):** wraps `GestureDetector`/`InkResponse`-free
feedback: on press, tint the background by 6 % (`ink` at 6 % alpha) and scale to
0.98 with `AnimatedScale` (`instant`). No ripple/ink splash (cheaper, more
premium). Hover (web): same tint at 4 %. Focus (web/keyboard): 2 px outline
`primary`, offset 2. Min hit area 48x48. Provide `onTapDown`-based callback
`onPrefetch` for warming data (section 10).

| Component                        | Spec                                                                                                                                                                                                                                                                                                                                                 |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PrimaryButton`                  | pill, height 56 (48 compact variant), fill `primary`, label `onPrimary` (`label` style), optional leading icon, full-width option, loading state = static label change (no spinner), disabled = 38 % alpha                                                                                                                                           |
| `SecondaryButton`                | pill, `surfaceSunken` fill + 1 px `line`, `ink` label                                                                                                                                                                                                                                                                                                |
| `GhostButton`                    | text-only, `primary`/`ink` label, 48 dp hit area                                                                                                                                                                                                                                                                                                     |
| `DangerButton`                   | pill, `danger` at 12 % fill, `dangerText` label (used for "Desci")                                                                                                                                                                                                                                                                                   |
| `IconBtn`                        | 48 dp hit area, 24 dp icon, circular pressed tint; always has a tooltip/semantic label                                                                                                                                                                                                                                                               |
| `Chip` / `FilterChip`            | pill, height 36 (hit area 48), `surfaceSunken`, selected = `primary` fill with `onPrimary`; optional leading dot/icon                                                                                                                                                                                                                                |
| `Segmented`                      | custom 2-4 segment control (not Material `SegmentedButton`): sunken track, a single sliding thumb via `AnimatedAlign` (`fast`), `selectionClick` haptic; equal widths; wraps labels to two lines if needed                                                                                                                                           |
| `LineBadge`                      | rounded 999, min 40x28, `short` text (<= 3 chars; if missing derive initials from the name; if empty show a bus icon), fill from `LineColors.of`, text colour computed, optional `Hero` tag `line-badge-<key>`; sizes `s` (24 high), `m` (28), `l` (40)                                                                                              |
| `CertaintyBadge`                 | the only place certainty is drawn: icon + label in a pill; `live` = solid green dot + waves icon; `predicted` = dashed outline pill, indigo, spark icon, label "Previsão"; `scheduled` = clock icon, neutral; `stale` = amber, "Sem sinal". Compact variant is icon-only with semantics label                                                        |
| `LiveDot`                        | 8 dp dot; live = `live` with an expanding ring (one shared `AnimationController` via `LivePulse` inherited widget, paused when off-screen/reduced motion); others static                                                                                                                                                                             |
| `EtaText`                        | the hero number: value + unit in `etaHero`/`etaLarge` with tabular figures; formats via `formatEta` (section 5.1); `AnimatedSwitcher` (`fast`, fade + 4 dp slide) only when the text changes; width reserved with a stable `ConstrainedBox` to avoid jitter; carries the certainty colour only on the badge, never on the digits (digits stay `ink`) |
| `ArrivalRow`                     | the core row (section 7): left ETA block, centre line badge + destination + subtitle, right action slot (chevron, bell later); card radius 16, `surface` + 1 px `line`; height >= 72; full-row tap target; semantics sentence (section 12)                                                                                                           |
| `LineRow`                        | compact list row: `LineBadge`, line name (2 lines max), terminals subtitle, trailing small `EtaText`/`LiveDot`; height 64-72; star toggle optional                                                                                                                                                                                                   |
| `VehicleRow`                     | "Ônibus 1" (numbered by order, **never by internal id**), age ("há 8 s"), speed, `CertaintyBadge`, "Seguir" ghost button                                                                                                                                                                                                                             |
| `ShortcutCard`                   | 156x112 card: icon (home/work/school/university/custom), label, line badge, next arrival `EtaText` (size `etaLarge`), certainty; empty state "Adicionar casa" ghost card with dashed border                                                                                                                                                          |
| `SectionHeader`                  | `title` style + optional trailing `GhostButton` ("Ver todas"); 24 dp top spacing                                                                                                                                                                                                                                                                     |
| `SearchField`                    | 52 dp, `surfaceSunken`, 16 radius, leading search icon, clear button, autofocus on the search screen; **no Material `TextField` underline/filled defaults**                                                                                                                                                                                          |
| `Sheet` (bottom sheet container) | 24 top radius, drag handle 36x4, `surface`, hairline top border, the one allowed shadow, `RepaintBoundary`                                                                                                                                                                                                                                           |
| `TimeRail`                       | timetable layout (section 7.6): hour label column + wrapping minute chips, sticky hour headers optional, past dimmed, "next" highlighted                                                                                                                                                                                                             |
| `Banner`                         | inline strip for offline/maintenance/permission info: icon + text + optional action; colours from `warning`/`danger`/`ink` roles                                                                                                                                                                                                                     |
| `Toast`                          | transient message (3 s) above the dock, `surfaceRaised`, one line, optional action; replaces `SnackBar` styling; queue max 1                                                                                                                                                                                                                         |
| `EmptyState`                     | small vector illustration (2-4 shapes via `CustomPainter`), title, one sentence, one action; never an image file                                                                                                                                                                                                                                     |
| `Skeleton`                       | static rounded rects in `surfaceSunken`; one shared opacity pulse (`FadeTransition`, 1.2 s) driven by a single controller; shown only after 300 ms of loading                                                                                                                                                                                        |
| `TripDock`                       | section 7.1                                                                                                                                                                                                                                                                                                                                          |
| `VehicleMarker`                  | section 7.5 (custom painted)                                                                                                                                                                                                                                                                                                                         |
| `PermissionCard`                 | explains a permission state and offers the platform-correct action (section 7.7, 8)                                                                                                                                                                                                                                                                  |
| `Sparkline`                      | later: 7-12 bars drawn with `CustomPainter` for delay history (flagged)                                                                                                                                                                                                                                                                              |
| `ConfidenceMeter`                | later: three small bars (low/medium/high) for predictions (flagged)                                                                                                                                                                                                                                                                                  |

### 5.1 ETA formatting (pure Dart, unit-tested)

`formatEta(ArrivalVM a, DateTime now)` returns `{ primary, secondary, a11y }`:

| Situation                                                                                                                                                                                                                    | primary                       | secondary                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ----------------------------------------------- |
| live or predicted, < 60 s                                                                                                                                                                                                    | `Agora` (predicted: `~Agora`) | `Chegando`                                      |
| live or predicted, 1-59 min                                                                                                                                                                                                  | `4 min` (predicted: `~4 min`) | optional clock time `14:35`                     |
| live or predicted, >= 60 min                                                                                                                                                                                                 | `1 h 05`                      | clock time                                      |
| scheduled, any                                                                                                                                                                                                               | clock time `14:35`            | countdown `em 12 min` (or `em 1 h 05`, `agora`) |
| scheduled in the past (late timetable)                                                                                                                                                                                       | `14:35`                       | `já saiu` (dimmed row)                          |
| stale                                                                                                                                                                                                                        | `há 3 min`                    | `Última posição`                                |
| Rules: use `Intl`-free manual formatting (no heavy locale init); minutes are `ceil` for countdowns so "0 min" never appears; never show negative numbers; a11y string is a natural sentence ("Chega em 4 minutos, ao vivo"). |                               |                                                 |

### 5.2 `NowTicker` (the only clock in the UI)

One provider emits `DateTime now` aligned to the **start of each minute**
(re-aligned on app resume). All countdowns watch it with `select` on their
minute value. A second variant ticks every second **only** while the Trip sheet
is visible. No per-widget `Timer`s anywhere.

---

## 6. UI architecture

### 6.1 Folder layout (adapt to the repo; do not move existing files without reason)

```
lib/ui/
  design/
    tokens/            # colors.dart, text.dart, spacing.dart, motion.dart, line_colors.dart
    theme/             # theme.dart (light/dark ThemeData + extensions)
    components/        # all components in section 5
    icons/             # custom painters (bus, waves, spark, ...)
    gallery/           # debug-only component gallery
  shell/               # adaptive scaffold, navigation, trip dock host, banners, toasts, route transitions
  features/
    home/  search/  lines/  line/  timetable/  trip/  settings/  system/
  adapters/            # view-model providers that read existing data/domain providers (no logic changes)
  models/              # UI view-models (section 6.2)
  util/                # formatEta, normalizeText, haptics, platform helpers
```

Rules: UI code may read domain/data providers only through `adapters/`.
`features/*` never import each other (share through `design/` or `models/`).
Files stay under ~300 lines; widgets are small and `const` where possible.

### 6.2 View-models (create what is missing; names may adapt)

```dart
enum Certainty { live, predicted, scheduled, stale }

@immutable class LineVM {            // everything optional except key and name
  const LineVM({required this.key, required this.name, this.short, this.terminals = const [], this.isLive = false,
                this.liveVehicleCount = 0, this.supportsSharing = false, this.color});
  final String key; final String name; final String? short; final List<String> terminals;
  final bool isLive; final int liveVehicleCount; final bool supportsSharing; final Color? color;
}
@immutable class ArrivalVM {         // the ONE shape for any "bus arrives at X at Y"
  const ArrivalVM({required this.lineKey, required this.at, required this.certainty, required this.asOf,
                   this.stopKey, this.headsign, this.originLabel, this.confidence, this.delaySeconds});
  final String lineKey; final String? stopKey; final DateTime at; final Certainty certainty; final DateTime asOf;
  final String? headsign, originLabel; final int? confidence /*0..2, predicted only*/; final int? delaySeconds;
}
@immutable class VehicleVM {
  const VehicleVM({required this.key, required this.lineKey, required this.lat, required this.lng,
                   this.headingDeg, this.speedKmh, required this.ageSeconds, required this.certainty, this.ordinal});
  /* key = internal id, never displayed; ordinal = 1,2,3 shown to users */
}
@immutable class ShortcutVM { /* kind: home|work|school|university|custom, label, lineKey, originLabel? or stopKey? */ }
@immutable class AlertRuleVM { /* later: lineKey, stopKey?, minutesBefore, days, active */ }
@immutable class ReliabilityVM { /* later: typicalDelayMin, sampleSize, bars: List<double> (aggregates only) */ }
```

### 6.3 Data seams (so future features plug in without UI rewrites)

```dart
/// The UI asks for arrivals; it does not care whether they come from a timetable, live data or a model.
abstract interface class ArrivalsSource {
  Stream<List<ArrivalVM>> watch(ArrivalQuery query);   // query: lineKey?, stopKey?, limit, originLabel?
}
class TimetableArrivalsSource implements ArrivalsSource { /* NOW: from static timetables; certainty = scheduled */ }
class LiveAwareArrivalsSource implements ArrivalsSource { /* LATER: overlays live/predicted when the backend provides ETA */ }
class CompositeArrivalsSource implements ArrivalsSource { /* merges sources, live wins over predicted wins over scheduled */ }
```

Same pattern for `SearchProvider` (lines now; stops and places later),
`ShortcutsStore`, `RecentsStore`, `FavoritesStore` (local, `shared_preferences`,
tiny JSON, versioned keys), and `AlertsStore` (later). Screens depend on the
interfaces only.

### 6.4 Feature flags

`Features` (compile-time defaults + optional overrides from the remote
`config.json` the app already fetches): `shortcuts` (on), `recents` (on),
`favorites` (on), `dataSaver` (on), `predictions` (off), `eta` (off),
`arrivalAlerts` (off), `reliability` (off), `followVehicle` (on), `routeLine`
(on if route data exists). **A disabled feature renders nothing** (no greyed
buttons, no "coming soon"). Components for off features exist and are tested so
flipping a flag is a small change.

### 6.5 Responsive system

```dart
enum Breakpoint { compact /*<600*/, medium /*600-839*/, expanded /*>=840*/ }
```

`AdaptiveScaffold` chooses: **compact** = bottom navigation + `TripDock` above
it + bottom sheet over map; **medium** = navigation rail (80 dp) + content,
sheet becomes a 360 dp side panel on the line screen; **expanded** = rail + 400
dp side panel + map filling the rest, content max width 720 on non-map screens
(centered, two-column card grids). Use `LayoutBuilder`/`MediaQuery.sizeOf` (not
`MediaQuery.of`) to avoid rebuilds from unrelated changes. Landscape phones use
the medium layout rules.

### 6.6 Navigation (go_router, keep the project's routing package)

Top-level destinations are data-driven: `[Início, Linhas, Ajustes]` today; the
list is built from enabled features so a future `Mapa`/`Alertas` tab is an
addition, not a rewrite. Routes (path strategy as the project already uses for
GitHub Pages; hash or path with the existing 404 trick): `/` (Início),
`/search`, `/lines`, `/line/:key` (query `?tab=agora|horarios`), `/trip`,
`/settings`, `/privacy`, `/privacy/policy`, `/privacy/terms`, `/about`,
`/system/:kind`. Deep link to `/line/:key` must work on web and be resilient to
unknown keys (show "Linha não encontrada" with a way back). Transitions:
fade-through 200 ms with 8 dp upward slide; the line badge uses a `Hero`; **no
Hero involving the map**.

`/trip` is pushed over the current route. The minimize chevron and system back
pop back to the screen that started sharing (line details, map tab, search)
with its state intact; home is the fallback when there is no route below. The
line screen closes its viewer socket while a full page covers it and reopens it
on return; bottom sheets and dialogs do not pause it. See
`DECISIONS.md#D77-2026-10-20`.

### 6.7 State rules

- Riverpod (or the project's state manager): fine-grained providers, `select`
  for single fields, `autoDispose` for map/line providers, no giant "UI state"
  objects.
- Vehicle updates must not rebuild lists: keep `Map<String, VehicleVM>` and a
  per-vehicle `family` provider so one marker repaints on its own.
- Pure functions (`formatEta`, `normalizeText`, `LineColors`, sorting, grouping)
  live in `util/` and have unit tests.
- Never call `setState` for data that comes from providers; local ephemeral
  state only (focus, sheet position, selected tab).
- Do not start streams in `build`; start them in providers/notifiers tied to
  route lifetime (the data layer's lifecycle rules, e.g. close the live stream
  when the line screen is left or the app is backgrounded, stay as they are).

---

## 7. Screens

Conventions: wireframes are compact-width (about 360-412 dp). `[ ]` = button,
`( )` = chip/badge, `●))` = live waves icon, `◐` = scheduled/clock icon, `⟡` =
prediction spark. Copy shown is final pt-BR unless marked (copy deck in section
14). Every screen must implement **all** listed states.

### 7.1 App shell (all screens)

```
┌────────────────────────────────────┐
│                                    │
│          (screen content)          │
│                                    │
│  ┌──────────────────────────────┐  │
│  │ ●))  Estou no ônibus       › │  │  TripDock (idle pill, 56 dp)
│  └──────────────────────────────┘  │
│  Início      Linhas      Ajustes   │  bottom navigation (64 dp + safe area)
└────────────────────────────────────┘
```

**Bottom navigation:** 3 destinations (data-driven, section 6.6). Selected =
filled icon + bold label + soft `primary` 12 % pill behind the icon; unselected
= outline icon + `inkMuted` label. Labels always visible. Surface = `surface`
with a 1 px top `line`. No ripple. Haptic `selectionClick`. Re-tapping the
active tab scrolls to top. Android system navigation bar colour = `surface` with
correct icon brightness (edge-to-edge).

**TripDock** (global, above the bottom navigation; hidden on `/trip`, `/search`,
when the keyboard is open, and on the line screen only if the line is not
shareable and no trip is active):

- **Idle:** pill 56 dp, `primary` fill, `●))` icon + "Estou no ônibus" (on a
  shareable line screen: "Estou neste ônibus", bound to that line) + chevron.
  Tap -> trip flow (7.7). One-time coachmark (7.10).
- **Starting:** label "Iniciando…" (static, no spinner), disabled.
- **Active:** bar `surfaceRaised` + 1 px `live` border: `LiveDot` +
  "Compartilhando · {linha}" + elapsed time (`mm:ss`, from `NowTicker` minute
  resolution; seconds only on `/trip`) + chevron. Tap/swipe-up -> `/trip`. **No
  destructive action on the bar** (avoid accidental end).
- **Reconnecting / paused:** same bar, amber border, text "Sem conexão. Tentando
  de novo" or "GPS desligado" with the relevant action when tappable.
- Position: 12 dp above the nav, 16 dp side margins, max width 420 centered on
  larger screens. In the **expanded** layout the dock sits at the bottom of the
  side panel.

**Banner slot** (top, under the status bar): offline ("Sem conexão. Mostrando
dados salvos."), maintenance, update available. Appears/disappears with a 140 ms
height+fade, never covers content, never blocks input.

**Toast slot:** above the dock; one at a time; 3 s; actionable ("Desfazer") only
when the action exists.

### 7.2 Início (Home) `/`

```
┌────────────────────────────────────┐
│ pontual                 ●)) 3 ao vivo│  wordmark + live summary chip (hidden if unknown)
│                                    │
│ Boa tarde                          │  display
│ Para onde vamos?                   │  body, inkMuted
│ ┌────────────────────────────────┐ │
│ │ ⌕  Buscar linha ou bairro      │ │  SearchField (tap opens /search)
│ └────────────────────────────────┘ │
│                                    │
│ Seus atalhos                       │  SectionHeader
│ ┌───────────┐┌───────────┐┌─────── │  horizontal list, snap, 156x112
│ │ ⌂ Casa    ││ ▤ Trabalho││ ＋ Ad… │
│ │ (AC)      ││ (SG)      ││        │
│ │ 12 min    ││ 14:35     ││        │
│ │ ●)) Ao vivo││ ◐ Horário ││        │
│ └───────────┘└───────────┘└─────── │
│                                    │
│ Ao vivo agora                      │  only if >= 1 live line
│ ┌────────────────────────────────┐ │
│ │ (AC) Aroeira / Cohab           │ │  LineRow card
│ │ ●)) 1 ônibus · atualizado há 8 s ›│ │
│ └────────────────────────────────┘ │
│                                    │
│ Recentes                           │  only if any
│ (AC)(SG)(SC)                       │  chips with LineBadge + short name
│                                    │
│ Todas as linhas                Ver › │  link row to /lines
└────────────────────────────────────┘
```

Behaviour:

- Paints from cache in the first frame (lines are static data). Live info
  (`live summary`) fills in without layout jump: reserve the chip height; "Ao
  vivo agora" section appears with a 140 ms fade only when data arrives.
- **Greeting** from local time: 05:00-11:59 "Bom dia", 12:00-17:59 "Boa tarde",
  otherwise "Boa noite". Subtitle fixed.
- **Shortcuts** (local, flag `shortcuts`): cards sorted by earliest next
  arrival; unconfigured "Adicionar" cards last. Each card's value uses
  `ArrivalsSource` (today: next scheduled departure from the chosen origin; if
  the line has live vehicles, show a small `●)) Ao vivo` badge instead of
  pretending to know an ETA). Tap -> `/line/:key`. Long press -> sheet (Editar,
  Remover). Add flow: sheet "Adicionar atalho": type (Casa, Trabalho, Escola,
  Faculdade, Outro + custom label) -> line (searchable list) -> origin terminal
  (chips; skipped if the line has one terminal) -> Salvar. Max 8 shortcuts.
- **Ao vivo agora:** lines with live vehicles (from the live summary), most
  vehicles first, max 5, then "Ver todas ao vivo" -> `/lines?filter=live`.
- **Recentes:** last 6 opened lines (local), `Chip` with `LineBadge` and the
  line name's first 14 chars.
- Pull-to-refresh refreshes the live summary (min 10 s between refreshes). No
  timers.
- **States:** _no live lines_ -> small `EmptyState` card "Nenhum ônibus
  compartilhando agora" with GhostButton "Ver horários" and the sharing hint;
  _offline_ -> banner, content still works; _first run_ -> Welcome card (7.10);
  _shortcuts empty_ -> four ghost cards (Casa, Trabalho, Escola, Faculdade) each
  opening the add flow with the type preselected.
- Desktop/web expanded: two-column grid (shortcuts + live cards left,
  recents/links right), content max width 720.

### 7.3 Busca `/search`

```
┌────────────────────────────────────┐
│ ←  ┌──────────────────────────┐    │
│    │ ⌕  aroeira            ✕  │    │  SearchField autofocus
│    └──────────────────────────┘    │
│                                    │
│ Linhas                             │
│ ┌────────────────────────────────┐ │
│ │ (AC) **Aroeira** / Cohab       │ │  match highlighted (bold, no colour only)
│ │      Aroeira · Cohab        ›  │ │
│ └────────────────────────────────┘ │
│ (empty query:)                     │
│ Recentes             Limpar        │
│ ...                                │
│ Sugestões (live lines first)       │
└────────────────────────────────────┘
```

- **Local, instant, offline.** Index built once from lines (name, short code,
  terminals, area tags) with `normalizeText` (lowercase, strip diacritics,
  collapse spaces). Tokenised AND match; ranking: exact short code > name prefix
  > terminal prefix > contains. Results update on every keystroke with no
  debounce (hundreds of lines is sub-millisecond).
- Results are **grouped by kind** through the `SearchProvider` interface (kind:
  line now; stop, place later) so new kinds add a group without UI changes.
  Group header only when more than one kind exists.
- Empty query: Recentes (last 8 searches or opened lines, "Limpar") then
  Sugestões (live lines first).
- No results: `EmptyState` "Nada encontrado" + tip "Tente o nome do bairro ou o
  código da linha".
- Keyboard: Enter opens the first result; Esc/back closes; Up/Down move focus
  through results (web); `/` focuses the field from anywhere on web.
- Back returns to the previous screen with the keyboard dismissed.

### 7.4 Linhas `/lines`

```
┌────────────────────────────────────┐
│ Linhas                             │  title (collapses on scroll)
│ 21 linhas                          │  count from data, never hard-coded
│ (Todas)(Ao vivo)(Favoritas)        │  FilterChips
│ ┌────────────────────────────────┐ │
│ │(AC) Aroeira / Cohab        ☆   │ │  LineRow
│ │     Aroeira · Cohab            │ │
│ │     ●)) 1 ao vivo   Próx. 12 min│ │
│ └────────────────────────────────┘ │
│ ...                                │
└────────────────────────────────────┘
```

- Sorted: live first, then favourites, then name (pt-BR collation,
  accent-insensitive). Virtualized `SliverList.builder` with a prototype/fixed
  extent.
- Star toggles a favourite (local); `selectionClick` haptic; optimistic.
- Filters are chips with counts only when cheap (live count is known). Empty
  states per filter ("Nenhuma linha ao vivo agora", "Toque na estrela para
  favoritar").
- Row subtitle shows terminals joined with " · " (ellipsis). Missing fields
  collapse gracefully.

### 7.5 Linha (line detail) `/line/:key` - the hero screen

Layout compact: **full-bleed map + draggable bottom sheet**. The dock floats
above the sheet.

```
Peek (default)                          Half                                   Full ("Horários" tab)
┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
│ (←)            © OSM  │   │ (←)            © OSM  │   │ ▔▔▔ (handle)          │
│        (map)          │   │      (map, smaller)   │   │ (AC) Aroeira / Cohab ☆│
│    ●))  bus markers   │   │                       │   │ [ Agora ][ Horários ] │
│        ~~~ route      │   ├───────────────────────┤   │ Dias úteis|Sáb|Dom    │
│                       │   │ ▔▔▔                   │   │ Saída de: [Aroeira ▾] │
├───────────────────────┤   │ (AC) Aroeira / Cohab ☆│   │ Próximo  14:35 em 12m │
│ ▔▔▔                   │   │ ●)) Ao vivo · 2 ônibus│   │ 05 | 30 50            │
│ (AC) Aroeira / Cohab ☆│   │ Ônibus agora          │   │ 06 | 10 40            │
│ ●)) Ao vivo · 2 ônibus│   │ ┌───────────────────┐ │   │ 07 | 05 25 45         │
│ ┌───────────────────┐ │   │ │Ônibus 1 há 8s 32km│ │   │ ...                   │
│ │ 12 min   Aroeira  │ │   │ └───────────────────┘ │   └───────────────────────┘
│ │ ◐ Horário  ›      │ │   │ Próximas saídas       │
│ └───────────────────┘ │   │ ┌───────────────────┐ │
└───────────────────────┘   │ │ 14:35 em 12 min   │ │
 [ ●)) Estou neste ônibus ]  └───────────────────────┘
```

**Sheet:** 3 snap points as screen-height fractions: **peek 0.30** (min 220 dp),
**half 0.55**, **full 0.92**. Implemented with `DraggableScrollableSheet` (or an
equivalent single-controller design). The sheet content is a `CustomScrollView`
of slivers; the map sits **outside** the sheet's rebuild path inside a
`RepaintBoundary`. When the sheet settles, call the map's camera fit with bottom
padding = visible sheet height (**only on settle, never per frame**). Initial
snap: peek (the map is the first thing seen). Tapping a vehicle moves the sheet
to peek.

**Sheet content "Agora" (peek -> half):**

1. Header: `LineBadge(l)` (Hero), name (`headline`, 2 lines), terminals
   (`caption`), star, status chip (live / stale / only timetable / no live).
2. **Next departure hero** (`ArrivalRow` large): ETA + certainty badge.
3. **Ônibus agora** (only when live vehicles exist): `VehicleRow`s, max 5.
4. **Próximas saídas:** next 3 `ArrivalRow`s (timetable today; live/predicted
   later through `ArrivalsSource`).
5. Secondary actions row: "Ver horários" (switches tab), later: bell/alerts.
   Tabs (`Segmented`): **Agora** | **Horários** | (flag) **Histórico**.

**Dock on this screen:** contextual "Estou neste ônibus" when the line supports
sharing; otherwise hidden. Never duplicate the CTA inside the sheet.

**Map layer details (`lib/ui/features/line/map/`):**

- Deferred-load the map code on web (`import ... deferred as map;`). While it
  loads show the `bg` colour with the line badge centered and a one-line
  "Carregando mapa" (static). On Android load normally.
- `TileSource` abstraction (the project already has or should have one): default
  OSM raster, `retinaMode` off, min zoom 12, max zoom 17 (data saver 16), camera
  constrained to the service-area bounds (existing config), **identifying
  User-Agent/package name set**, attribution chip visible at all times
  (top-right, 12 sp, `surface` 85 % alpha pill) and tappable to the OSM
  copyright page. **Never prefetch or bulk-download tiles.**
- **Premium muting without cost:** one `ColoredBox(color: mapScrim)` above the
  tile layer (no `ColorFiltered`, no blend modes, no blur). Light theme uses
  light tiles + 18 % paper scrim. Dark theme: if a dark raster source is
  approved (ADR, VERIFY terms and keys), use it; otherwise **keep light tiles
  with a 35 % dark scrim** and white marker rings. Never invert tiles with a
  filter (GPU cost).
- **Route polyline** (flag `routeLine`, only if route data exists): 8 dp casing
  in `bg` colour under a 5 dp line in the line colour, round joins/caps.
  Predicted path ahead of a bus (later): 4 dp dashed `predicted` colour
  (`StrokePattern.dashed` in current flutter_map; VERIFY the API for the pinned
  version).
- **Markers:** `VehicleMarker` (below), max ~20 rendered; anything beyond is
  summarised in the sheet.
- **Controls:** back button (top-left, 44 dp circle, `surface` fill + hairline),
  two locate buttons in one bottom-right column above the
  dock (viewer dot at zoom 14, city centre fallback; closest bus to the
  viewer at zoom 15, camera-centre reference and city fallback otherwise),
  zoom +/- only on pointer devices (web expanded). No rotation gesture.
  No compass.
- **Camera:** on enter fit to live vehicles (if any) else route bounds else
  service-area center at zoom 13. The fit runs from the first build that has
  a map (lines load async, so never once from `initState`), plus at most one
  refit when vehicles arrive after an empty first fit and the user has not
  panned. Sheet movement never moves the camera. The recenter control
  centres the viewer dot at zoom 14 (city centre at zoom 13 when the viewer
  position is unknown). Throttled tile bursts reload automatically with a
  bounded backoff (max 3 attempts per burst); failed tiles are evicted when
  pruned. User pan cancels follow mode; "Seguir" on a
  `VehicleRow` (flag `followVehicle`) smoothly follows that bus (400 ms ease to
  marker; chip "Seguindo Ônibus 1 ✕" at top-center).
- **User location is not shown** while only viewing (no location access for
  viewers; privacy rule).

**VehicleMarker spec (`CustomPainter`, one `RepaintBoundary` per map layer, not
per marker):**

| Part                                                                                                                                                                                                                                                                             | Spec                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Body                                                                                                                                                                                                                                                                             | 36 dp circle (44 dp hit area), fill = line colour, 3 dp ring in `surface` (light) / `surfaceRaised` (dark)                                                             |
| Glyph                                                                                                                                                                                                                                                                            | `BusIcon` 18 dp, white or near-black per contrast                                                                                                                      |
| Heading                                                                                                                                                                                                                                                                          | small triangle (8 dp) outside the ring at `headingDeg`, only if speed >= 1.5 m/s and heading known                                                                     |
| Live                                                                                                                                                                                                                                                                             | pulse ring radius 18 -> 30 dp, alpha 30 % -> 0, 1600 ms, driven by the shared `LivePulse` controller; **stops when reduced motion, app paused, or screen not visible** |
| Aging (20-45 s)                                                                                                                                                                                                                                                                  | normal, label shows "há N s" when selected                                                                                                                             |
| Stale (> 45 s)                                                                                                                                                                                                                                                                   | grey ring, fill 55 % alpha, no pulse, label "Sem sinal"                                                                                                                |
| Predicted (later)                                                                                                                                                                                                                                                                | **dashed** indigo ring, fill 25 % alpha, "~" label chip, `⟡` icon; never a pulse                                                                                       |
| Selected                                                                                                                                                                                                                                                                         | scale 1.12, label bubble above: "Ônibus 1 · há 8 s"                                                                                                                    |
| **Movement:** when a new position arrives, interpolate over 800 ms (linear) with a **single shared `Ticker`** that runs only while at least one marker is animating; jump (no animation) if the move is > 300 m or reduced motion is on. Never create one controller per marker. |                                                                                                                                                                        |

**States:** _loading_ (static bg + badge, <= 300 ms before anything extra), _no
live vehicles_ (EmptyState card in the sheet, map shows the route only), _stale_
(amber chip "Última posição há 3 min"), _offline_ (banner + last known vehicles
dimmed), _unknown line key_ (`EmptyState` "Linha não encontrada" + back),
_non-shareable line_ (no dock CTA, note "Esta linha ainda não tem rastreamento
ao vivo. Veja os horários.").

**Expanded layout:** left 400 dp panel (the sheet content, scrollable, no drag),
right map; the dock sits at the bottom of the panel.

### 7.6 Horários (timetable tab)

```
┌────────────────────────────────────┐
│ ┌────────────────────────────────┐ │
│ │ Próximo   14:35                │ │  hero ArrivalRow (scheduled)
│ │ ◐ Horário · em 12 min          │ │
│ └────────────────────────────────┘ │
│ ┌───────┬───────┬────────────────┐ │
│ │Úteis  │ Sáb   │ Dom/Feriados   │ │  Segmented (default = today)
│ └───────┴───────┴────────────────┘ │
│ Saída de  (Aroeira)(Cohab)         │  origin chips (hidden if one origin)
│                                    │
│ 05 │ (30) (50)                     │  TimeRail
│ 06 │ (10) (40)                     │
│ 14 │ (05) (25) [35] (55)           │  next = filled primary chip
│ ...                                │
│ Horários não oficiais. Atualizado  │
│ em 05/10/2026 · Fontes             │  footnote (caption)
└────────────────────────────────────┘
```

- Day default from the **local São Mateus date** (Sat -> Sábado, Sun ->
  Domingo/Feriados; holidays are not auto-detected, the user can switch).
- Hour rail: hour in `title` style (tabular), minute chips in `label`; past
  minutes at 45 % opacity **by colour alpha, not `Opacity`**; the next departure
  highlighted; the list auto-scrolls so the next hour sits near the top third
  (animate only if far; instant if reduced motion).
- Built with a lazy builder, one row per hour present in the data (hours are
  data, not a fixed 24).
- Empty ("Sem horários cadastrados para este dia"), unknown origin handling, and
  very long hour rows (wrap).
- The footnote is always visible at the end and links "Fontes" to the About
  sources.

### 7.7 Compartilhar viagem (trip flow)

**Entry:** dock tap. If no line is bound: a **line chooser sheet** ("Em qual
linha você está?") lists sharing-capable lines (live ones first), searchable, no
hard-coded count.

**Step 1 - Consent sheet** (modal bottom sheet; shown before the first trip and
whenever the consent version changes; text identical on Android and Web):

```
┌────────────────────────────────────┐
│  ▔▔▔                               │
│  (small phone → bus vector)        │
│  Compartilhar sua localização      │  title
│  Para mostrar onde o ônibus está,  │
│  coletamos a localização do seu    │
│  celular enquanto a viagem estiver │
│  ativa, inclusive com a tela       │
│  bloqueada ou o app em segundo     │
│  plano (no Android).               │
│  ✓ Só serve para posicionar o ônibus│
│  ✓ Não é ligada a nome, e-mail ou  │
│    telefone                        │
│  ✓ É apagada quando a viagem acaba │
│  ✓ Outros veem o ônibus, não quem  │
│    está nele. Se só você compartilha,│
│    a posição do ônibus é a sua.    │
│  ✓ Você encerra quando quiser      │
│  Política de Privacidade           │
│  [      Aceitar e continuar     ]  │
│  [          Agora não           ]  │
└────────────────────────────────────┘
```

Rules: no pre-ticked boxes; dismissible without side effects; the web copy
replaces "inclusive com a tela bloqueada..." with "enquanto esta página estiver
aberta"; acceptance recorded through the existing consent call; if offline, keep
the existing retry behaviour.

**Step 2 - Permission flow.** Pre-prompt sheet: "Para compartilhar, o Pontual
precisa da localização **enquanto o app estiver em uso**. Não pedimos
localização 'o tempo todo'." [Continuar] -> OS/browser prompt. Platform handling
is in the matrix below and section 8.

**Permission state matrix:**

| State                              | Android                                                                                                                                                                                                                   | Web                                                                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Not asked                          | pre-prompt -> OS dialog                                                                                                                                                                                                   | pre-prompt -> browser prompt (must be triggered by the tap)                                                                       |
| Granted                            | continue                                                                                                                                                                                                                  | continue                                                                                                                          |
| Denied (can ask again)             | `PermissionCard`: "A permissão de localização está desligada. Sem ela não dá para compartilhar a viagem." [Tentar de novo] [Cancelar]                                                                                                  | same (some browsers re-ask, some do not; fall through to blocked)                                                                 |
| Denied permanently                 | same text + **[Abrir ajustes]** -> `Geolocator.openAppSettings()` (VERIFY the project's plugin); when the app returns to foreground (`AppLifecycleState.resumed`) re-check automatically and continue the flow if granted | **no settings link exists**: show browser-specific steps (below) + [Já permiti, tentar de novo] which re-checks without reloading |
| Location services off              | "Ative a localização do aparelho." [Abrir ajustes] -> `Geolocator.openLocationSettings()`; auto re-check on resume                                                                                                        | "Não conseguimos sua localização. Verifique se a localização do aparelho está ligada e tente de novo." [Tentar de novo]          |
| Notifications denied (Android 13+) | non-blocking note: "Sem as notificações, o Android pode encerrar o compartilhamento. Permita para manter o envio ativo." The trip may continue                                                                                          | not applicable (no notification on web trips)                                                                                     |
| Insecure context / unsupported     | n/a                                                                                                                                                                                                                       | "Seu navegador não permite compartilhar a localização aqui." + link to supported browsers                                         |

**Web "blocked" steps** (detect browser family from the user agent; show only
the relevant block, plain language):

- _Chrome / Edge (Android or desktop):_ "Toque no cadeado ao lado do endereço >
  Permissões > Localização > Permitir. Depois toque em Tentar de novo."
- _Safari (iPhone):_ "Toque em aA na barra do endereço > Ajustes do site >
  Localização > Permitir."
- _Firefox:_ "Toque no cadeado > Permissões > Localização > Permitir."
- _Unknown:_ generic sentence with the same idea. Add a small static
  illustration of the address-bar lock icon (vector shapes, no image).

**Step 3 - Trip active (`/trip`)** (full-screen, no map, no animation except one
soft ring pulse; CPU ~0):

```
┌────────────────────────────────────┐
│ ⌄  Compartilhando viagem           │  minimize chevron (pops back to the previous screen, dock stays)
│                                    │
│            ((  ●  ))               │  LiveDot hero (static if reduced motion)
│        Você está ajudando          │
│        quem espera o ônibus        │  headline
│    (AC) Aroeira / Cohab            │
│        há 12 min                   │  elapsed, tabular, 5 s tick
│                                    │
│  ┌ métricas (um cartão) ─────────┐ │
│  │ GPS            ±8 m           │ │  accuracy from the last accepted fix
│  │ ▓▓▓▓▓▓▓▓▓░░░  Aceito até 60 m │ │  meter against the 60 m publish gate
│  │ Satélites      7              │ │  signal quality, Android only
│  │ ▓▓▓▓▓▓▓▓░░░░  de 12 em vista  │ │  meter is the real used/in-view
│  │ Envio          15 s           │ │  server interval, never a client guess
│  │ Com mais frequência           │ │  role explains the cadence
│  └───────────────────────────────┘ │
│  ┌ dica (dismissible, Android) ┐   │
│  │ Se parar sozinho, defina a  │   │
│  │ bateria do app como "Sem    │   │
│  │ restrições".                │   │
│  └─────────────────────────────┘   │
│                                    │
│ [      Desci - encerrar viagem   ] │  DangerButton 56 dp, bottom, thumb reach
└────────────────────────────────────┘
```

States: _waiting_ ("Aguardando o ônibus…"), _leader_ ("Enviando com mais
frequência. Revezamos a cada poucos minutos para poupar a bateria de todos."),
_follower_ ("Outras pessoas também compartilham, então enviamos menos vezes."),
_offline_ ("Sem conexão. Vamos retomar assim que voltar."), _paused_
(permission/GPS banner with the action), _web_ (extra banner "Mantenha esta tela
aberta e o celular desbloqueado." + tip to lower brightness + wake-lock status).
Rules: the word "líder/seguidor/ping/cluster" never appears. The end button is
the only large control; ending is immediate (no confirm), followed by the end
card. The metrics card shows only measured values: GPS accuracy, satellites
used and in view, and the server send interval. Missing values read
"Procurando sinal", "Sem leitura" or "Sem conexão"; no placeholder number is
invented. The GPS and satellite meters compare a real value to the publish gate
(60 m) and to the satellites in view; the send metric has no meter. Satellites
come from the Android GNSS channel; elsewhere the cell reads "Indisponível no
navegador". On screens of 600 dp and wider the three metrics sit in one row;
below that, and whenever the text scale is above 1.3, they stack.

**Step 4 - End card** (full-screen card, 2 s of delight then calm): checkmark
draws in (stroke animation 400 ms, skipped on reduced motion), "Viagem
encerrada. Obrigado por ajudar!", reason line when automatic (idle, timeout,
permission removed, inconsistent data, maintenance), [Voltar às linhas].
Optional local-only counter "Você já ajudou N viagens" (stored on device only,
flag `localKudos`, off by default). No share button, no history, no stats sent
anywhere.

**Auto prompt (RF16 behaviour):** "Você ainda está no ônibus?" [Sim, continuar]
[Desci]; no answer in 3 min ends the trip (existing logic; the UI only presents
it).

### 7.8 Ajustes, Privacidade, Sobre

```
┌────────────────────────────────────┐
│ Ajustes                            │
│ Aparência                          │
│  Tema        (Sistema)(Claro)(Escuro)│
│  Economia de dados            [ ○─]│
│  Reduzir animações            [ ○─]│
│ Compartilhamento                   │
│  Como funciona                   › │
│  Dicas de bateria (Android)      › │
│ Privacidade e dados              › │
│ Sobre o Pontual                  › │
│  versão 1.4.0 · horários 05/10/2026│
└────────────────────────────────────┘
```

- **Economia de dados** (flag `dataSaver`): the line screen opens **list-first**
  with the map collapsed behind a "Ver no mapa" button (tiles load only on
  request), max zoom 16, no marker animation, no route polyline download, no
  decorative animation. Persisted locally; also auto-suggested via a one-time
  toast when the platform reports a data-saver connection (Android
  `ConnectivityManager` via the project's existing mechanism, only if already
  available; do not add a plugin).
- **Reduzir animações:** overrides to match the OS setting.
- **Privacidade e dados:** "Política de Privacidade", "Termos de Uso" (bundled
  text, readable offline; link to the canonical web page), "O que coletamos"
  (6-line summary), **"Apagar meus dados"** (confirm dialog: "Isso encerra sua
  viagem, apaga os dados ligados a este aparelho no servidor e reinicia o app."
  [Cancelar] [Apagar]; offline -> honest message, never fake success), "Revogar
  consentimento".
- **Sobre:** "App independente e não oficial. Não é da Viação São Gabriel nem da
  Prefeitura de São Mateus.", data sources list, "© OpenStreetMap contributors"
  link, open-source licences screen (own simple list from `LicenseRegistry`,
  lazily loaded, tokens applied), contact link, repository link, version.
- No login, no avatar, no promotional content.

### 7.9 System screens and states

- **Maintenance:** centered `EmptyState` (wrench built from shapes) "Serviço em
  manutenção. Os horários continuam disponíveis." [Ver horários] [Tentar de
  novo].
- **Update required:** "Atualize o app para continuar." [Atualizar] (store link
  on Android; reload on web). Timetables stay usable.
- **Server unavailable / waking up:** "Servidor indisponível no momento. Tente
  de novo em instantes." with bounded retries, then the generic error.
- **Offline:** banner only; never a blocking screen.
- **Not found / generic error:** friendly `EmptyState` with a way back; never a
  stack trace; log without personal data.

### 7.10 First run

- **No onboarding wall.** The app opens on Início. A one-time dismissible
  **Welcome card** at the top: "Veja onde o ônibus está. Quem está dentro
  compartilha a posição, de forma anônima. Sem cadastro, sem anúncios." +
  "Entendi" + "Como funciona a privacidade". Permissions are never requested
  here.
- A one-time **coachmark** (small bubble pointing at the dock, 6 s, tap to
  dismiss): "Está no ônibus? Toque aqui." Stored in local prefs.

---

## 8. Platform differences: Android vs Web

One codebase, platform-aware behaviour behind a small `Platform` helper
(`isWeb`, `isAndroid` via `kIsWeb` and `defaultTargetPlatform`; no `dart:io` in
shared code). Anything not listed behaves identically.

| Topic                        | Android                                                                                                                                            | Web (GitHub Pages)                                                                                                                                                                                                                                                                |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Location permission settings | `openAppSettings` / `openLocationSettings` through the project's location plugin (VERIFY the exact calls); re-check on `AppLifecycleState.resumed` | **cannot open settings**: show browser-specific steps and a "Tentar de novo" button (7.7)                                                                                                                                                                                         |
| Trip while screen is off     | yes (foreground service, existing logic)                                                                                                           | **no**: needs screen on + page open; show the foreground banner, request a Screen Wake Lock if supported, pause after the page is hidden for 60 s                                                                                                                                 |
| Notifications                | trip notification (existing); Android 13+ runtime permission                                                                                       | none for trips; future arrival alerts need Web Push + installed PWA on iOS (see 13.4)                                                                                                                                                                                             |
| Back navigation              | system back and **predictive back** (Android 14+): use `PopScope`; back from `/trip` minimises to the screen that opened it (home when there is none) instead of ending; back closes sheets first | browser back/forward and URL must work; the app updates the URL for line routes; `Esc` closes sheets and search                                                                                                                                                                   |
| System bars                  | edge-to-edge, transparent status/navigation bars, correct icon brightness per theme (`SystemUiOverlayStyle`), safe-area aware                      | `<meta name="theme-color">` for light and dark; no safe-area except iOS notch (`viewport-fit=cover` + `env(safe-area-inset-*)` handled by `MediaQuery.padding`)                                                                                                                   |
| Input                        | touch gestures, haptics                                                                                                                            | mouse + keyboard + touch: hover tint, `SystemMouseCursors.click`, visible focus ring, shortcuts (`/` search, `Esc` close, arrows in lists, `Enter` activate), mouse-wheel scroll, draggable scrollbars on desktop, click-and-drag scrolling enabled via a custom `ScrollBehavior` |
| Pull to refresh              | yes                                                                                                                                                | desktop has no pull gesture: show a small refresh `IconBtn` in the header on pointer devices                                                                                                                                                                                      |
| Layout                       | compact/medium/expanded by size                                                                                                                    | same breakpoints; desktop gets the side-panel map layout and centred max-width content                                                                                                                                                                                            |
| Startup                      | native splash (Android 12 splash API: brand `#0B3D36` background + mark), `runApp` immediately                                                     | **inline HTML/CSS splash** (below) removed on the first Flutter frame; map code deferred                                                                                                                                                                                          |
| Icons/branding               | adaptive icon (background `#0B3D36`, mint mark) + **monochrome** layer for themed icons                                                            | favicon (SVG + 32 px PNG), `apple-touch-icon`, manifest icons (192/512, maskable), `theme-color`, Open Graph title/description                                                                                                                                                    |
| Fonts                        | bundled subset                                                                                                                                     | same files; avoid FOUT by waiting for the first frame (fonts are assets)                                                                                                                                                                                                          |
| Links                        | `url_launcher` external application                                                                                                                | same, `noopener`, never inside the app shell                                                                                                                                                                                                                                      |
| Install                      | Play Store (and the debug/APK distribution already in use)                                                                                         | optional PWA install: do not nag; a quiet "Instalar" item in Ajustes when the browser offers it (`beforeinstallprompt` via the project's existing JS interop if present; do not add a package)                                                                                    |
| Share/copy                   | n/a in alpha                                                                                                                                       | n/a                                                                                                                                                                                                                                                                               |
| Accessibility tree           | TalkBack via Flutter semantics                                                                                                                     | Flutter web builds the semantics tree on demand when assistive tech is detected; keep labels complete. Verify with a screen reader (NVDA/VoiceOver)                                                                                                                               |
| Deep links                   | not used                                                                                                                                           | `/line/:key` must load directly; GitHub Pages needs the project's existing `404.html` redirect or hash strategy; unknown routes render "Página não encontrada"                                                                                                                    |

**Web `index.html` splash (inline, no network, removed at first frame):**

```html
<style>
html,
body {
  margin: 0;
  height: 100%;
  background: #F6F5F1;
}
@media (prefers-color-scheme:dark) {
  html,
  body {
    background: #0A1110;
  }
}
#splash {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
}
#splash svg {
  width: 88px;
  height: 88px;
  animation: p 1.6s ease-in-out infinite;
}
@keyframes p {
  50% {
    opacity: .55;
  }
}
@media (prefers-reduced-motion:reduce) {
  #splash svg {
    animation: none;
  }
}
</style>
<div id="splash" aria-hidden="true">
  <!-- inline SVG of the brand mark (section 15) -->
</div>
<script>
window.addEventListener("flutter-first-frame", function () {
  var s = document.getElementById("splash");
  if (s) s.remove();
});
</script>
```

Also set `<html lang="pt-BR">`,
`<meta name="color-scheme" content="light dark">`,
`<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`,
a meaningful `<title>` ("Pontual - ônibus ao vivo em São Mateus") and
description. VERIFY the event name against the pinned Flutter version.

---

## 9. Motion and micro-interactions

All durations/curves from section 4.4. Nothing here may add a persistent ticker;
every animation ends.

| Element                                                                                                   | Trigger                           | Motion                                                                          | Notes                                                 |
| --------------------------------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Page change                                                                                               | route push/pop                    | fade-through 200 ms + 8 dp upward slide; line badge `Hero`                      | no Hero on maps; reduced motion: 80 ms fade           |
| Press feedback                                                                                            | pointer down                      | tint 6 % + scale 0.98, `instant`                                                | everywhere via `Pressable`                            |
| Segmented / chip select                                                                                   | tap                               | thumb slides (`AnimatedAlign`, `fast`), colour crossfade                        | `selectionClick` haptic                               |
| ETA digits                                                                                                | value changes                     | `AnimatedSwitcher` fade + 4 dp slide, `fast`; width reserved by tabular figures | only when the text changes                            |
| Certainty change                                                                                          | live replaces predicted/scheduled | ghost -> solid over `base`, badge cross-fades                                   | the "promise becomes fact" moment                     |
| Live pulse                                                                                                | continuous while visible          | ring 18 -> 30 dp, alpha 30 -> 0, 1600 ms                                        | one shared controller; off when hidden/reduced motion |
| Marker move                                                                                               | new position                      | 800 ms linear lerp                                                              | one shared ticker; snap if > 300 m                    |
| Sheet                                                                                                     | drag/fling                        | framework spring + snap                                                         | settle -> fit map camera once                         |
| Skeleton                                                                                                  | loading > 300 ms                  | one shared 1.2 s opacity pulse                                                  | none for cached content                               |
| Toast / banner                                                                                            | show/hide                         | height + fade 140 ms                                                            |                                                       |
| Trip start                                                                                                | success                           | rings expand once on the hero dot (400 ms), `mediumImpact`                      | Peak moment                                           |
| Trip end                                                                                                  | end                               | checkmark draws (stroke 400 ms), `lightImpact`                                  | Peak-End rule                                         |
| List items                                                                                                | appear                            | **none** (no staggered entrances: they cost frames and delay content)           |                                                       |
| Pull to refresh                                                                                           | gesture                           | built-in indicator                                                              |                                                       |
| Reduced motion removes pulses, marker interpolation, drawing animations, and shortens fades to `instant`. |                                   |                                                                                 |                                                       |

---

## 10. Loading, empty, error and offline patterns ("Instant UI")

1. **Paint from cache first.** Lines/timetables are static and bundled: every
   screen except live data renders at once. Keep the last live snapshot per line
   in memory and show it dimmed with its age while refreshing.
2. **Stale-while-revalidate.** Never blank a screen to refresh it. Show
   "atualizado há N s" in `caption` when data is older than 20 s.
3. **150 ms rule:** show no loading indicator before 150 ms; **300 ms rule:**
   show skeletons/static placeholders only after 300 ms. Placeholders reserve
   final dimensions (no layout shift).
4. **Prefetch intent.** On pointer hover (web) and `onTapDown` (touch), warm the
   next screen's data (live snapshot for the line) through the existing data
   layer's cached call. Cheap, conditional, and cancelled implicitly if unused.
5. **Optimistic UI** for local actions (favourite, shortcut save, theme): update
   immediately.
6. **Errors:** inline, specific, actionable, never blaming ("Não foi possível
   atualizar o ao vivo. Tentar de novo"). One retry button per failure area, not
   per widget. No dialogs for recoverable errors.
7. **Offline:** global banner + dimmed live data with ages; actions that need
   the network say so at the moment of use, never silently fail.
8. **Empty states** are designed moments: small vector illustration (2-4
   shapes), one sentence that explains, one action that helps. Examples in
   section 14.
9. **Skeletons never shimmer.** One shared opacity pulse at most.
10. **Never trap the user:** every state offers a way back or forward.

---

## 11. Performance engineering rules (Flutter specific)

### 11.1 Do

- `const` constructors everywhere possible; split big `build` methods into small
  widget **classes** (not helper methods) so rebuilds are scoped.
- `select` on providers; per-item `family` providers for vehicles; `autoDispose`
  for map/line providers.
- Slivers and `SliverList.builder`/`ListView.builder` with `itemExtent` or
  `prototypeItem` for uniform rows; stable `ValueKey`s for reorderable/filtered
  rows.
- Colours with alpha via `Color.withValues(alpha: ...)` (or the pinned Flutter's
  equivalent), `ColoredBox`, `DecoratedBox` with `BoxDecoration` borders and
  radii (hairline borders are cheaper than shadows).
- `RepaintBoundary` **only** around hot repainters proven by profiling: the map
  layer, the marker layer, the live pulse, the sheet shadow, the dock.
- Custom painters for icons, markers, sparkline: cheap, crisp, tiny.
- Lazy-load heavy screens: **deferred import for the map on web**.
- `NowTicker` (minute-aligned) as the single clock;
  `TickerMode`/visibility-aware animations; pause everything on
  `AppLifecycleState.paused`.
- Keep text styles as `const`/cached (no `copyWith` chains inside `build`).
- Cache `normalizeText`, line colours, formatted strings per `(line, minute)`.

### 11.2 Don't

- No `Opacity` widget (use alpha on colours, `FadeTransition`, `AnimatedOpacity`
  only for single leaf widgets); no `BackdropFilter`, `ImageFiltered`,
  `ColorFiltered`, `ShaderMask`, `Material` elevation shadows in lists, big
  blurred `BoxShadow`s, nested `ClipRRect` over large areas (use `Clip.hardEdge`
  or decoration radii), `saveLayer` triggers, `IntrinsicHeight/IntrinsicWidth`,
  `shrinkWrap: true` on long lists, `Visibility`-hidden heavy subtrees (remove
  them), `FutureBuilder`/`StreamBuilder` creating futures in `build`, `setState`
  on whole screens for small changes, per-widget `Timer`s, per-marker
  `AnimationController`s, images/PNG/GIF/Lottie, runtime font loading, regex or
  JSON work in `build`.
- No gradients beyond the single subtle optional hero gradient; no animated
  gradients.
- No logging in hot paths in release.

### 11.3 Startup

`main()` runs `runApp` immediately; initialise everything else after the first
frame (`addPostFrameCallback`). No `await` before the first frame. Fonts are
assets, so no loading flash. Lines render from bundled data. Web: the HTML
splash covers the engine boot; use the project's current release build flags
(CanvasKit default; evaluate `--wasm` where supported, VERIFY the pinned Flutter
version's options and the removal of the old `--web-renderer` flag) and
`deferred` imports.

### 11.4 Tooling and measurement

- Profile with `flutter run --profile` + DevTools (Performance, CPU, Memory);
  `--trace-startup` for startup; `adb shell am start -W` (Android cold start);
  Lighthouse (web); `flutter build apk --analyze-size` /
  `flutter build web --analyze-size` (or the pinned version's equivalent) for
  size.
- Debug aids while tuning (never shipped): `debugRepaintRainbowEnabled`,
  `showPerformanceOverlay`, DevTools "Track widget rebuilds".
- Lints to enable: `prefer_const_constructors`,
  `prefer_const_literals_to_create_immutables`, `prefer_const_declarations`,
  `sized_box_for_whitespace`, `use_colored_box`, `use_decorated_box`,
  `avoid_unnecessary_containers`, `unnecessary_const`, `cancel_subscriptions`,
  `close_sinks`, `unawaited_futures`.
- Add a small debug-only frame-timing logger
  (`SchedulerBinding.instance.addTimingsCallback`) that prints p50/p95 build and
  raster times for each screen during manual QA.

---

## 12. Accessibility spec

1. **Semantics sentences (natural pt-BR):** an arrival row reads like speech,
   for example: "Linha Aroeira Cohab. Chega em 4 minutos, ao vivo." / "Linha
   Aroeira Cohab. Próxima saída às 14 e 35, em 12 minutos. Horário previsto pela
   tabela." / "Previsão: chega em cerca de 4 minutos. Não é uma posição ao
   vivo." Vehicle rows: "Ônibus 1, atualizado há 8 segundos, 32 quilômetros por
   hora." Group related text with `MergeSemantics`; hide decorative shapes with
   `ExcludeSemantics`.
2. **Live updates:** announce meaningful changes politely and throttled (at most
   once per 30 s per line), for example "2 ônibus ao vivo na linha Aroeira" via
   `SemanticsService.announce`. Do not announce every position update.
3. **Focus management:** after opening a sheet/dialog focus moves into it; after
   closing it returns to the trigger; sheets set `scopesRoute`/`namesRoute`; the
   map is a single semantic region ("Mapa da linha, {n} ônibus") with the
   vehicle list as the accessible alternative.
4. **Targets:** every interactive element >= 48x48 dp (44 minimum), >= 8 dp
   apart.
5. **Text scale:** test 1.0, 1.5 and 2.0 on a 360 dp-wide screen: no clipping or
   overlap; rows grow in height; badges keep min size and use `FittedBox` only
   for the `short` code.
6. **Contrast:** automated test over all token pairs (4.1); manual review in
   both themes; verify line badge colours.
7. **Colour independence:** certainty and status use shape + icon + text; review
   screenshots under protanopia/deuteranopia simulation.
8. **Motion:** honour `MediaQuery.disableAnimations` and the in-app toggle; no
   flashing; nothing animates longer than 2 s except the optional live pulse.
9. **Keyboard (web):** logical tab order, visible focus ring, `Enter`/`Space`
   activate, `Esc` closes overlays, `/` focuses search, arrow keys move within
   lists/segmented controls; no keyboard traps.
10. **Forms:** the search field and shortcut form have labels, hints, and error
    text announced.
11. **Language:** `lang="pt-BR"`; numbers/time read correctly (use "14 e 35"
    semantics or `HH:mm` text with a clear label).
12. **Automated checks in widget tests:**
    `meetsGuideline(androidTapTargetGuideline)`,
    `meetsGuideline(iOSTapTargetGuideline)`,
    `meetsGuideline(labeledTapTargetGuideline)`,
    `meetsGuideline(textContrastGuideline)` on every screen state.
13. **Manual script** (`docs/ui/a11y-script.md`): TalkBack walk-through of
    Início -> Linha -> start/end trip; VoiceOver/NVDA on web; keyboard-only run.

---

## 13. Future features: how the UI receives them

The UI is built so each future feature is mostly **data + a flag**, not a
redesign. Components and models already exist (section 5 and 6); flags are off
until the backend provides data. A disabled feature renders nothing.

| Feature                                                                  | UI slot / component                                                                                                              | Model / seam                              | Flag                      | Backend dependency                     |
| ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ------------------------- | -------------------------------------- |
| **Bus ETA** at a stop/terminal                                           | `ArrivalRow` hero on Linha, Home shortcut cards, stop sheet                                                                      | `ArrivalVM` via `LiveAwareArrivalsSource` | `eta`                     | stops + ETA endpoint                   |
| **Bus moving on the map**                                                | `VehicleMarker` + `MarkerAnimator` (already built)                                                                               | `VehicleVM` stream                        | on                        | none (uses live stream)                |
| **Bus icon**                                                             | `BusIcon` painter in markers, badges, empty states                                                                               | n/a                                       | on                        | none                                   |
| **"Arrives in X min at my stop" notification**                           | bell `IconBtn` in `ArrivalRow` and stop sheet; `AlertSheet` (below)                                                              | `AlertRuleVM`, `AlertsStore`              | `arrivalAlerts`           | server push + stops (see 13.4)         |
| **Recent buses**                                                         | Home "Recentes" chips (built now)                                                                                                | `RecentsStore`                            | on                        | none                                   |
| **Next buses to home/work/school/university, ordered by first arriving** | Home "Saindo agora" section (`ArrivalRow`s for shortcut targets sorted by `at`); shortcut cards already sort by earliest arrival | `ShortcutVM` + `ArrivalsSource`           | `shortcuts` on, ETA later | timetable now, ETA later               |
| **Bus history: arrival and delay**                                       | `ReliabilityCard` in the Linha "Histórico" tab (typical delay + `Sparkline`)                                                     | `ReliabilityVM` (aggregates only)         | `reliability`             | aggregated history API (de-identified) |
| **Last position + prediction of movement**                               | `GhostMarker` (dashed), `PredictedPath` (dashed polyline), `ConfidenceMeter`, `PredictionInfoSheet`, `~` ETA prefix              | `Certainty.predicted`, `confidence`       | `predictions`             | prediction endpoint                    |

### 13.1 Prediction UX (never pass a prediction off as live)

1. Always the `predicted` style: dashed ring/ghost marker, indigo, `~` prefix,
   "Previsão" badge, spark icon.
2. The ghost bus **moves along the route** at the predicted pace from the last
   real fix, driven by the shared marker ticker; the real marker stays visible
   (solid) at the last known position with its age ("há 25 s").
3. `ConfidenceMeter` (3 bars: baixa/média/alta) is derived from data freshness
   and sample size, shown next to the badge; low confidence also widens wording
   ("por volta de 4 a 6 min").
4. When a real fix arrives the ghost **snaps** to it (200 ms) and the style
   flips to live.
5. `PredictionInfoSheet` ("Como calculamos"): one short paragraph (copy in
   section 14) explaining the estimate uses the most recent positions and the
   usual pace of this line/time of day, and is not a guarantee.
6. After ~2 minutes without a live fix the prediction fades out and the vehicle
   becomes `stale` instead of extrapolating forever.
7. **Pace data rule (owner decision):** the driver is anonymous and **only the
   current pace is stored**. Pace is therefore a property of the live vehicle
   (for example a `paceFactor` = recent speed along the route divided by the
   usual speed for that segment and time of day), kept **in memory for the life
   of the vehicle** and dropped with it. It is never tied to a persistent bus,
   plate or driver id, never stored per driver, and never accumulated into
   per-driver history across trips. Long-term behaviour (typical delay, usual
   pace) comes only from **de-identified aggregates** per line, direction,
   segment and time of day. The UI never names or hints at an individual (copy
   says "este ônibus" and "ritmo recente"), shows pace only as a plain phrase
   inside the prediction explanation and next to the `ConfidenceMeter`, and
   never ranks or compares vehicles. Predictions that need a driver's habits
   across trips are out of scope unless the privacy design changes. (Backend
   note: this needs a `paceFactor` field on the in-memory vehicle and in the
   snapshot; the UI reads it as optional.)

### 13.2 Arrival alerts (UI only; behaviour flagged)

- Bell on an `ArrivalRow` or stop sheet -> `AlertSheet`: "Avisar quando faltar"
  with chips **[2 min] [5 min] [10 min]** (custom value later), day-of-week
  chips (default: today), a toggle "Repetir nos dias úteis", [Salvar]. Alerts
  list lives in Ajustes > Alertas (flag).
- Permission flow reuses `PermissionCard` (Android 13+ notifications; Web
  notification permission).

### 13.3 Next-buses feed ("Saindo agora")

Home section listing, for the user's shortcuts of kind
home/work/school/university, the **next arrival of each**, sorted ascending by
`at`, each an `ArrivalRow` with the shortcut icon. Empty until at least one
shortcut exists. When ETA data exists it silently upgrades certainty from
`scheduled` to `live`/`predicted` with no layout change.

### 13.4 Notifications architecture note (for the owner)

The project forbids Firebase and third-party telemetry. True "your bus arrives
in 5 min" alerts while the app is closed need a **push channel**: Web Push
(VAPID, own server; iOS only for installed PWAs) and, on Android, an approach
that fits the privacy rules (for example UnifiedPush or periodic work with
limits). That is a backend/architecture decision; the UI only needs
`AlertRuleVM`, `AlertsStore` and the permission flows above.

### 13.5 Flexibility rules (lines, names and data will change)

- No catalogs in code: counts, names, terminals, tags and colours come from
  data; use `LineVM` with optional fields and graceful fallbacks (no `short` ->
  initials; no terminals -> hide the subtitle; very long names -> two lines then
  ellipsis; hundreds of lines -> virtualized lists, search stays instant).
- Unknown enum values (new certainty, day type, vehicle state) render a neutral
  fallback, never crash.
- Layouts use `Wrap`, `Flexible`, `Expanded`, and constraints; nothing assumes a
  fixed number of tabs, chips, shortcuts or vehicles.
- Strings come only from the strings file; ordinal/plural helpers handle 0, 1,
  many ("1 ônibus", "2 ônibus").
- Feature flags and `ArrivalsSource`/`SearchProvider` composition are the only
  extension points; do not branch on feature names inside widgets.

---

## 14. Copy deck (pt-BR)

Tone: short, warm, direct, second person (você), no jargon. Never use "líder",
"seguidor", "ping", "cluster", "token". Errors say what happened and what to do,
and never blame the user. Put every string in the project's strings file with
stable keys. Plurals and ordinals via small helpers (0, 1, many).

| Key                                                                                         | Text                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `appName`                                                                                   | Pontual                                                                                                                                                                                                                                                                     |
| `tagline`                                                                                   | Seu ônibus, na hora.                                                                                                                                                                                                                                                        |
| `greetMorning` / `greetAfternoon` / `greetEvening`                                          | Bom dia / Boa tarde / Boa noite                                                                                                                                                                                                                                             |
| `homeSubtitle`                                                                              | Para onde vamos?                                                                                                                                                                                                                                                            |
| `searchHint`                                                                                | Buscar linha ou bairro                                                                                                                                                                                                                                                      |
| `searchNoResults`                                                                           | Nada encontrado                                                                                                                                                                                                                                                             |
| `searchTip`                                                                                 | Tente o nome do bairro ou o código da linha                                                                                                                                                                                                                                 |
| `recents` / `clear`                                                                         | Recentes / Limpar                                                                                                                                                                                                                                                           |
| `suggestions`                                                                               | Sugestões                                                                                                                                                                                                                                                                   |
| `shortcuts`                                                                                 | Seus atalhos                                                                                                                                                                                                                                                                |
| `shortcutHome` / `shortcutWork` / `shortcutSchool` / `shortcutUniversity` / `shortcutOther` | Casa / Trabalho / Escola / Faculdade / Outro                                                                                                                                                                                                                                |
| `shortcutAdd`                                                                               | Adicionar                                                                                                                                                                                                                                                                   |
| `shortcutAddTitle`                                                                          | Adicionar atalho                                                                                                                                                                                                                                                            |
| `shortcutEdit` / `shortcutRemove`                                                           | Editar / Remover                                                                                                                                                                                                                                                            |
| `liveNow`                                                                                   | Ao vivo agora                                                                                                                                                                                                                                                               |
| `liveCount`                                                                                 | `{n}` ônibus ao vivo / 1 ônibus ao vivo                                                                                                                                                                                                                                     |
| `liveUpdated`                                                                               | atualizado há `{n}` s                                                                                                                                                                                                                                                       |
| `seeAll`                                                                                    | Ver todas                                                                                                                                                                                                                                                                   |
| `allLines`                                                                                  | Todas as linhas                                                                                                                                                                                                                                                             |
| `linesCount`                                                                                | `{n}` linhas                                                                                                                                                                                                                                                                |
| `filterAll` / `filterLive` / `filterFavorites`                                              | Todas / Ao vivo / Favoritas                                                                                                                                                                                                                                                 |
| `emptyLive`                                                                                 | Nenhuma linha ao vivo agora                                                                                                                                                                                                                                                 |
| `emptyFavorites`                                                                            | Toque na estrela de uma linha para adicioná-la aos favoritos                                                                                                                                                                                                                |
| `noVehicles`                                                                                | Nenhum ônibus ao vivo agora                                                                                                                                                                                                                                                 |
| `noVehiclesHint`                                                                            | Está no ônibus? Toque em "Estou no ônibus" e mostre a posição para quem espera. Sem cadastro.                                                                                                                  |
| `onlyTimetable`                                                                             | Só horários                                                                                                                                                                                                                                                                 |
| `lineNotTrackable`                                                                          | Esta linha ainda não tem rastreamento ao vivo. Veja os horários.                                                                                                                                                                                                            |
| `lineNotFound`                                                                              | Linha não encontrada                                                                                                                                                                                                                                                        |
| `certaintyLive` / `certaintyPredicted` / `certaintyScheduled` / `certaintyStale`            | Ao vivo / Previsão / Horário / Sem sinal                                                                                                                                                                                                                                    |
| `lastSeen`                                                                                  | Última posição há `{n}` min                                                                                                                                                                                                                                                 |
| `now` / `arriving`                                                                          | Agora / Chegando                                                                                                                                                                                                                                                            |
| `inMinutes`                                                                                 | em `{n}` min                                                                                                                                                                                                                                                                |
| `alreadyLeft`                                                                               | já saiu                                                                                                                                                                                                                                                                     |
| `vehicleN`                                                                                  | Ônibus `{n}`                                                                                                                                                                                                                                                                |
| `follow` / `following`                                                                      | Seguir / Seguindo Ônibus `{n}`                                                                                                                                                                                                                                              |
| `tabNow` / `tabTimetable` / `tabHistory`                                                    | Agora / Horários / Histórico                                                                                                                                                                                                                                                |
| `nextDepartures`                                                                            | Próximas saídas                                                                                                                                                                                                                                                             |
| `busesNow`                                                                                  | Ônibus agora                                                                                                                                                                                                                                                                |
| `next`                                                                                      | Próximo                                                                                                                                                                                                                                                                     |
| `departFrom`                                                                                | Saída de                                                                                                                                                                                                                                                                    |
| `dayWeekday` / `daySaturday` / `daySunday`                                                  | Dias úteis / Sábado / Dom e feriados                                                                                                                                                                                                                                        |
| `timetableDisclaimer`                                                                       | Horários não oficiais, reunidos de fontes públicas. Podem estar desatualizados. Atualizados em `{date}`.                                                                                                                                                                     |
| `timetableEmpty`                                                                            | Sem horários cadastrados para este dia                                                                                                                                                                                                                                      |
| `dockIdle` / `dockIdleLine`                                                                 | Estou no ônibus / Estou neste ônibus                                                                                                                                                                                                                                        |
| `dockStarting`                                                                              | Iniciando…                                                                                                                                                                                                                                                                  |
| `dockActive`                                                                                | Compartilhando · `{line}`                                                                                                                                                                                                                                                   |
| `dockOffline` / `dockGpsOff`                                                                | Sem conexão. Tentando de novo / GPS desligado                                                                                                                                                                                                                               |
| `chooseLineTitle`                                                                           | Em qual linha você está?                                                                                                                                                                                                                                                    |
| `consentTitle`                                                                              | Compartilhar sua localização                                                                                                                                                                                                                                                |
| `consentBody` (Android)                                                                     | Para mostrar onde o ônibus está, coletamos a localização do seu celular enquanto a viagem estiver ativa, inclusive com a tela bloqueada ou o app em segundo plano.                                                                                                          |
| `consentBody` (Web)                                                                         | Para mostrar onde o ônibus está, coletamos a localização do seu aparelho enquanto esta página estiver aberta durante a viagem.                                                                                                                                              |
| `consentPoints`                                                                             | Só serve para posicionar o ônibus no mapa. / Não é ligada a nome, e-mail ou telefone. / É apagada quando a viagem termina. / Outros veem a posição do ônibus, não quem está nele. Se só você compartilhar, a posição do ônibus é a sua. / Você pode encerrar quando quiser. |
| `consentAccept` / `consentDecline`                                                          | Aceitar e continuar / Agora não                                                                                                                                                                                                                                             |
| `privacyPolicy`                                                                             | Política de Privacidade                                                                                                                                                                                                                                                     |
| `permPre`                                                                                   | Para compartilhar, o Pontual precisa da sua localização enquanto o app estiver em uso. Não pedimos localização o tempo todo.                                                                                  |
| `permContinue`                                                                              | Continuar                                                                                                                                                                                                                                                                   |
| `permDenied`                                                                                | A permissão de localização está desligada. Sem ela não dá para compartilhar a viagem.                                                                                                                        |
| `permRetry` / `permOpenSettings` / `permAlreadyAllowed`                                     | Tentar de novo / Abrir ajustes / Já permiti, tentar de novo                                                                                                                                                                                                                 |
| `permLocationOff`                                                                           | Ative a localização do aparelho.                                                                                                                                                                                                                                            |
| `permNotifNote`                                                                             | Sem as notificações, o Android pode encerrar o compartilhamento. Permita para manter o envio ativo.                                                                                                          |
| `permWebUnsupported`                                                                        | Seu navegador não permite compartilhar a localização aqui.                                                                                                                                                                                                                  |
| `permWebChrome`                                                                             | Toque no cadeado ao lado do endereço > Permissões > Localização > Permitir. Depois toque em Tentar de novo.                                                                                                                                                                 |
| `permWebSafari`                                                                             | Toque em aA na barra do endereço > Ajustes do site > Localização > Permitir.                                                                                                                                                                                                |
| `permWebFirefox`                                                                            | Toque no cadeado > Permissões > Localização > Permitir.                                                                                                                                                                                                                     |
| `tripTitle`                                                                                 | Compartilhando viagem                                                                                                                                                                                                                                                       |
| `tripHero`                                                                                  | Você está ajudando quem espera o ônibus                                                                                                                                                                                                                                     |
| `tripWaiting`                                                                               | Aguardando o ônibus sair…                                                                                                                                                                                                                                                   |
| `tripActiveHigh`                                                                            | Enviando com mais frequência. Revezamos a cada poucos minutos para poupar a bateria de todos.                                                                                                                                                                               |
| `tripActiveEco`                                                                             | Outras pessoas também compartilham, então enviamos menos vezes.                                                                                                                                                                                                                          |
| `tripOffline`                                                                               | Sem conexão. Vamos retomar assim que voltar.                                                                                                                                                                                                                                |
| `tripConnection` / `tripGps`                                                                | Conexão / GPS                                                                                                                                                                                                                                                               |
| `connOk` / `connNone`                                                                       | Conectado / Sem conexão                                                                                                                                                                                                                                                     |
| `gpsGood` / `gpsWeak` / `gpsOff`                                                            | Bom / Fraco / Desligado                                                                                                                                                                                                                                                     |
| `tripBatteryTip`                                                                            | Se parar sozinho, defina a bateria do app como "Sem restrições".                                                                                                                                                                                                            |
| `webForeground`                                                                             | Mantenha esta tela aberta e o celular desbloqueado.                                                                                                                                                                                                                         |
| `webBrightness`                                                                             | A tela fica ligada durante a viagem. Abaixe o brilho para economizar bateria.                                                                                                                         |
| `tripEnd`                                                                                   | Desci - encerrar viagem                                                                                                                                                                                                                                                     |
| `stillOnBus`                                                                                | Você ainda está no ônibus?                                                                                                                                                                                                                                                  |
| `yesContinue` / `iGotOff`                                                                   | Sim, continuar / Desci                                                                                                                                                                                                                                                      |
| `tripEnded`                                                                                 | Viagem encerrada. Obrigado por ajudar!                                                                                                                                                                                                                                      |
| `endedIdle`                                                                                 | Encerramos porque o celular ficou parado por 10 minutos.                                                                                                                                                                                                                    |
| `endedTimeout`                                                                              | Encerramos porque a viagem atingiu o tempo máximo ou ficou sem sinal.                                                                                                                                    |
| `endedPermission`                                                                           | Encerramos porque a permissão de localização foi removida.                                                                                                                                                                                                                  |
| `endedAbuse`                                                                                | Encerramos por envios de localização inconsistentes.                                                                                                                                                                                                                        |
| `endedMaint`                                                                                | Serviço em manutenção. Tente mais tarde.                                                                                                                                                                                                                                    |
| `backToLines`                                                                               | Voltar às linhas                                                                                                                                                                                                                                                            |
| `settings`                                                                                  | Ajustes                                                                                                                                                                                                                                                                     |
| `appearance` / `theme`                                                                      | Aparência / Tema                                                                                                                                                                                                                                                            |
| `themeSystem` / `themeLight` / `themeDark`                                                  | Sistema / Claro / Escuro                                                                                                                                                                                                                                                    |
| `dataSaver`                                                                                 | Economia de dados                                                                                                                                                                                                                                                           |
| `dataSaverHint`                                                                             | Abre o mapa só quando você pedir e reduz animações.                                                                                                                                                                                                                         |
| `reduceMotion`                                                                              | Reduzir animações                                                                                                                                                                                                                                                           |
| `showMap`                                                                                   | Ver no mapa                                                                                                                                                                                                                                                                 |
| `sharing` / `howItWorks` / `batteryTips`                                                    | Compartilhamento / Como funciona / Dicas de bateria                                                                                                                                                                                                                         |
| `privacyData`                                                                               | Privacidade e dados                                                                                                                                                                                                                                                         |
| `terms`                                                                                     | Termos de Uso                                                                                                                                                                                                                                                               |
| `whatWeCollect`                                                                             | O que coletamos                                                                                                                                                                                                                                                             |
| `deleteMyData`                                                                              | Apagar meus dados                                                                                                                                                                                                                                                           |
| `deleteConfirm`                                                                             | Isso encerra sua viagem, apaga os dados ligados a este aparelho no servidor e reinicia o app.                                                                                                                                                                               |
| `deleteOffline`                                                                             | Sem conexão. Tente novamente quando estiver online.                                                                                                                                                                                                                         |
| `revokeConsent`                                                                             | Revogar consentimento                                                                                                                                                                                                                                                       |
| `about`                                                                                     | Sobre o Pontual                                                                                                                                                                                                                                                             |
| `notOfficial`                                                                               | App independente e não oficial. Não é da Viação São Gabriel nem da Prefeitura de São Mateus.                                                                                                                                                                                |
| `maintenance`                                                                               | Serviço em manutenção. Os horários continuam disponíveis.                                                                                                                                                                                                                   |
| `updateRequired`                                                                            | Atualize o app para continuar.                                                                                                                                                                                                                                              |
| `serverDown`                                                                                | Servidor indisponível no momento. Tente de novo em instantes.                                                                                                                                                                                                               |
| `offlineBanner`                                                                             | Sem conexão. Mostrando dados salvos.                                                                                                                                                                                                                                        |
| `capacity`                                                                                  | Muitas pessoas compartilhando agora. Tente em instantes.                                                                                                                                                                                                                    |
| `retry`                                                                                     | Tentar de novo                                                                                                                                                                                                                                                              |
| `liveFailed`                                                                                | Não foi possível atualizar o ao vivo.                                                                                                                                                                                                                                       |
| `welcomeTitle`                                                                              | Veja onde o ônibus está                                                                                                                                                                                                                                                     |
| `welcomeBody`                                                                               | Quem está dentro compartilha a posição, de forma anônima. Sem cadastro, sem anúncios.                                                                                                                                                                                       |
| `welcomeOk` / `welcomePrivacy`                                                              | Entendi / Como funciona a privacidade                                                                                                                                                                                                                                       |
| `coachDock`                                                                                 | Está no ônibus? Toque aqui.                                                                                                                                                                            |
| `predictionInfoTitle`                                                                       | Como calculamos                                                                                                                                                                                                                                                             |
| `predictionInfoBody`                                                                        | A previsão usa as posições mais recentes e o ritmo habitual desta linha neste horário. Ela é uma estimativa, não uma posição ao vivo, e pode mudar.                                                                                                                         |
| `scheduledInfoBody`                                                                         | Este horário vem da tabela publicada. Não é uma posição ao vivo.                                                                                                                                                                                                            |
| `alertTitle`                                                                                | Avisar quando faltar                                                                                                                                                                                                                                                        |
| `alertSave`                                                                                 | Salvar                                                                                                                                                                                                                                                                      |
| `typicalDelay`                                                                              | Costuma atrasar cerca de `{n}` min neste horário                                                                                                                                                                                                                            |
| `confLow` / `confMid` / `confHigh`                                                          | Confiança baixa / média / alta                                                                                                                                                                                                                                              |
| `paceFaster` / `paceNormal` / `paceSlower`                                                  | Ritmo recente deste ônibus: um pouco mais rápido que o normal / dentro do normal / um pouco mais lento que o normal                                                                                                                                                         |

---

## 15. Brand assets

- **Name:** Pontual (pt-BR for punctual; "ponto" is the bus stop). Wordmark:
  lowercase `pontual`, the bundled font at weight 800, letter spacing -0.5,
  `ink` (light) or `primary` mint (dark).
- **Mark ("live signal"):** a mint dot (the bus) emitting two arcs (the live
  signal) on deep pine. Vector source `design/brand/pontual-mark.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="112" fill="#0B3D36"/>
  <g transform="translate(-19 20)" fill="none" stroke="#62E8B0" stroke-width="26" stroke-linecap="round">
    <circle cx="214" cy="298" r="58" fill="#62E8B0" stroke="none"/>
    <path d="M233.1 189.7A110 110 0 0 1 322.3 278.9"/>
    <path d="M243.5 130.6A170 170 0 0 1 381.4 268.5" stroke-opacity=".55"/>
  </g>
</svg>
```

- **Android launcher icon:** adaptive icon, background `#0B3D36`, foreground =
  the mark (dot + arcs only) scaled to fit the 66 dp safe zone, plus a
  **monochrome** layer for themed icons. Generate with `flutter_launcher_icons`
  (dev dependency only). Android 12 splash: background `#0B3D36`, icon = the
  mark.
- **Web:** favicon (SVG + 32 px PNG), `apple-touch-icon` (180), manifest icons
  192 and 512 + maskable, `theme-color` `#F6F5F1` (light) and `#0A1110` (dark),
  Open Graph title "Pontual - ônibus ao vivo em São Mateus".
- **In-app use of the mark:** the HTML splash, About screen, empty states, and
  the end-of-trip card. The live waves icon is the same two-arc motif.
- Do not use operator names, colours or logos. Include the non-affiliation line
  in About and in the store/web description.

---

## 16. Implementation plan (tasks U01 to U26)

Each task is one prompt/PR. M/E = recommended model/effort (S5.5 Sonnet 5.5,
O5.5 Opus 5.5, H4.5 Haiku 4.5; L/M/H). After every task: format, analyze, tests,
build on Android and Web, and a screenshot of every affected state in light and
dark at text scale 1.0 and 2.0 (attach to the PR). Never leave the app broken.

### Phase 0 - Audit and safety net

| Task | Deliverable                                                                                                                                                                                                                                                            | Acceptance                                                                              | M/E    |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------ |
| U01  | `docs/ui/AUDIT.md`: map of existing screens, routes, providers, models, packages, how trip/map/data/consent flow, what is reused vs replaced, **baseline metrics** (cold start, frame p50/p95 on Home and Line, APK size, web transfer size, memory), device list used | every concept in this spec mapped to a repo name; baselines recorded with commands used | S5.5/M |
| U02  | Safety net: confirm tests pass; add smoke tests for the data/logic boundaries the UI depends on; add the `NEW_UI` compile-time switch and an empty `lib/ui/` entry that falls back to the old UI                                                                       | app runs identically with the flag off; CI green                                        | S5.5/M |

### Phase 1 - Design system

| Task | Deliverable                                                                                                                                                                                                                                                                         | Acceptance                                                                     | M/E    |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------ |
| U03  | Font chosen and **subsetted** (<= 70 KB), registered; custom icon painters (bus, waves, spark, route, terminal); brand SVG and generated launcher/splash/favicon/manifest assets; HTML splash                                                                                       | font passes the tnum + glyph checks; assets in place; no `google_fonts`        | S5.5/M |
| U04  | Tokens (`PontualColors`, text styles, spacing, radii, motion), `ThemeData` light/dark, `LineColors`, `contrast_test.dart`                                                                                                                                                           | contrast test green for all pairs; final hex values recorded in this spec      | S5.5/M |
| U05  | Components 1: `Pressable`, buttons, `IconBtn`, `Chip`, `Segmented`, `LineBadge`, `CertaintyBadge`, `LiveDot`/`LivePulse`, `EtaText` + `formatEta` + `NowTicker`, `Skeleton`, `Banner`, `Toast`, `SectionHeader`, `EmptyState` + debug gallery + widget tests + a11y guideline tests | gallery shows all in 2 themes x 2 text scales; `formatEta` fully unit-tested   | S5.5/M |
| U06  | Components 2: `LineRow`, `ArrivalRow`, `VehicleRow`, `ShortcutCard`, `SearchField`, `Sheet`, `TimeRail`, `PermissionCard`, `TripDock` (visual states only), `Sparkline`/`ConfidenceMeter` (flagged, tested)                                                                         | same as U05                                                                    | S5.5/M |
| U07  | Shell: `AdaptiveScaffold` (compact/medium/expanded), data-driven navigation, banner/toast slots, dock host, page transitions, routing structure, error/not-found screens                                                                                                            | navigation works on Android and Web at all breakpoints; no jank in transitions | S5.5/H |

### Phase 2 - Screens

| Task | Deliverable                                                                                                                                                                                      | Acceptance                                                                   | M/E    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- | ------ |
| U08  | Local stores (`ShortcutsStore`, `RecentsStore`, `FavoritesStore`, prefs flags) + `ArrivalsSource` interface + `TimetableArrivalsSource` + `SearchProvider` (lines) + adapters/view-models        | unit tests; no UI yet                                                        | S5.5/M |
| U09  | Início: header, greeting, search entry, shortcuts (add/edit/remove flow), live section, recents, welcome card, states                                                                            | all states in section 7.2; paints from cache in first frame                  | S5.5/H |
| U10  | Busca `/search` (normalisation, ranking, groups, recents, keyboard)                                                                                                                              | instant on 500 synthetic lines; web keyboard shortcuts work                  | S5.5/M |
| U11  | Linhas `/lines` (filters, sorting, favourites, virtualized)                                                                                                                                      | 500 synthetic lines scroll at 60 fps                                         | S5.5/M |
| U12  | Map layer: `TileSource` wiring, scrim, attribution chip, controls, `VehicleMarker` painter, `MarkerAnimator`, route polyline, deferred import on web; ADR on a muted/dark tile source (optional) | pan/zoom budget met on the low-end phone; attribution always visible         | O5.5/H |
| U13  | Linha screen: sheet (3 snaps), header, hero arrival, vehicle list, next departures, follow mode, states, expanded side-panel layout                                                              | camera fits on settle only; all states reachable; deep link works on web     | O5.5/H |
| U14  | Horários tab: `Segmented`, origin chips, `TimeRail`, auto-scroll, footnote                                                                                                                       | correct for all day types; offline; hours not hard-coded                     | S5.5/M |
| U15  | Trip flow part 1: line chooser, consent sheet, permission pre-prompt, **platform permission matrix** (Android settings, re-check on resume; Web browser steps and retry)                         | all rows of the matrix verified on a real Android phone and in Chrome/Safari | O5.5/H |
| U16  | Trip flow part 2: dock states, `/trip` screen (all states), end card, auto-prompt, web foreground banner/wake-lock status, haptics                                                               | solo trip works end to end on both platforms; screen has ~0 CPU              | O5.5/H |
| U17  | Ajustes, Privacidade (policy/terms/delete/revoke), Sobre (sources, OSM attribution, licences), data-saver mode                                                                                   | delete flow honest offline; licences screen lazy                             | S5.5/M |
| U18  | System screens (maintenance, update, server down), offline banner wiring, coachmark                                                                                                              | simulated flags show each state                                              | S5.5/M |

### Phase 3 - Polish and cutover

| Task | Deliverable                                                                                                                                                                     | Acceptance                                                                       | M/E    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------ |
| U19  | Motion and haptics pass (section 9), reduced-motion behaviour, `Hero` badge                                                                                                     | every animation matches the table; reduced motion verified                       | S5.5/M |
| U20  | Accessibility audit and fixes: semantics sentences, focus management, keyboard map, text scale 2.0, colour-blind review, TalkBack/VoiceOver/NVDA runs; `docs/ui/a11y-script.md` | all automated guideline tests green; manual script passed and recorded           | S5.5/H |
| U21  | Performance audit vs section 2.1 and U01 baseline; fixes (rebuild scopes, repaint boundaries, deferred loading, size)                                                           | table of before/after in `docs/ui/PERF.md`; budgets met or deviations documented | O5.5/H |
| U22  | Web specifics: `index.html` (splash, meta, theme-color), manifest/icons, hover/focus/keyboard, scrollbars, refresh button, 404/deep links, optional install item                | Lighthouse accessibility and best-practices >= 95; deep links work               | S5.5/M |
| U23  | Android specifics: edge-to-edge, predictive back (`PopScope`), splash, adaptive + monochrome icon, system bar styling, notification permission copy                             | verified on Android 12, 13, 14+ devices/emulators                                | S5.5/M |
| U24  | **Cutover:** remove the `NEW_UI` flag, delete the old UI, update README/screenshots/docs, final QA matrix (section 17)                                                          | old UI code gone; all checks green; release build size/perf recorded             | S5.5/M |

### Phase 4 - Future-feature scaffolding (flags off)

| Task | Deliverable                                                                                                                                                                                                         | Acceptance                                                                       | M/E    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------ |
| U25  | `Features` flags + `CompositeArrivalsSource`/`LiveAwareArrivalsSource` stubs; "Saindo agora" home section (hidden until data); `AlertSheet`, `ReliabilityCard`, `PredictionInfoSheet` built and tested behind flags | flags off = zero visual change; flipping a flag with fake data shows the feature | S5.5/M |
| U26  | Prediction visuals: `GhostMarker`, `PredictedPath`, certainty transition animation, with fake data in the gallery (flag `predictions` off)                                                                          | gallery demo meets 13.1 rules; no regression in map budget                       | O5.5/H |

---

## 17. QA, acceptance and measurement

### 17.1 Device and browser matrix

- **Android:** one low-end phone (<= 2 GB RAM, Android 9-11), one mid-range
  (Android 12-13), one recent (Android 14+), all with gesture navigation;
  emulator for Android 15 edge-to-edge.
- **Web:** Chrome Android, Safari iPhone (standalone and in-tab), Chrome and
  Firefox desktop at 1366x768 and 1920x1080, a narrow desktop window (400 px) to
  check compact layout.
- **Settings to test:** light/dark, text scale 1.0/1.5/2.0, reduced motion
  on/off, data saver on/off, offline, slow 3G (DevTools throttling), location
  permission in every state of 7.7.

### 17.2 Screens to screenshot (light and dark, text scale 1.0 and 2.0)

Início (empty shortcuts, with shortcuts, no live lines, with live lines,
offline), Busca (empty, results, no results), Linhas (all filters), Linha (peek,
half, full, no live, stale, non-shareable, not found), Horários (each day type,
empty), consent, each permission state on Android and Web, `/trip` (waiting,
high, eco, offline, paused, web), end card (each reason), Ajustes, Privacidade,
Sobre, system screens, gallery.

### 17.3 Acceptance checklist (cutover gate)

- [ ] All budgets in 2.1 met against the baseline; measurements recorded.
- [ ] No `Opacity`, `BackdropFilter`, `ColorFiltered`, `ShaderMask`, shimmer or
      per-marker controllers anywhere (grep + review).
- [ ] No timer/ticker/animation running on Início when nothing is changing
      (verified with DevTools).
- [ ] Certainty rules (section 3) hold on every screen; no predicted/scheduled
      value is styled as live.
- [ ] Every string is from the strings file; no em dashes; pt-BR reviewed.
- [ ] Contrast test, tap-target and label guideline tests green on all screens.
- [ ] TalkBack, VoiceOver/NVDA and keyboard-only scripts passed.
- [ ] Permission matrix verified on a real Android phone and in Chrome and
      Safari.
- [ ] Offline, slow network and server-down states verified.
- [ ] Privacy: no coordinates, tokens or ids in logs or UI; consent flow
      unchanged in behaviour; delete-my-data works.
- [ ] Old UI removed; docs updated; `DECISIONS.md` has the font choice,
      tile-source decision and any deviations.

### 17.4 Measurement protocol

Same device, same build mode, three runs, report the median: cold start to first
frame, Home first-paint to interactive, Linha open to map visible, map pan frame
timings (p50/p95), memory after 2 minutes on Linha, APK size and web transfer
size (`--analyze-size`). Store before/after in `docs/ui/PERF.md`.

---

## 18. Reading list and references

**Books (design and UX):** _Don't Make Me Think, Revisited_ (Steve Krug); _The
Design of Everyday Things_ (Don Norman); _Emotional Design_ (Don Norman);
_Refactoring UI_ (Adam Wathan, Steve Schoger); _Laws of UX_ (Jon Yablonski);
_Universal Principles of Design_ (Lidwell, Holden, Butler); _100 Things Every
Designer Needs to Know About People_ (Susan Weinschenk); _Design for How People
Think_ (John Whalen); _Mobile First_ (Luke Wroblewski); _Designing Interfaces_
(Jenifer Tidwell); _Microinteractions_ (Dan Saffer); _Inclusive Design Patterns_
(Heydon Pickering); _Atomic Design_ (Brad Frost); _The Elements of User
Experience_ (Jesse James Garrett); _The Non-Designer's Design Book_ (Robin
Williams). **Standards and guidelines:** WCAG 2.2 (W3C); Nielsen Norman Group's
10 usability heuristics; Material Design 3 and Apple Human Interface Guidelines
(platform behaviour reference only); Android accessibility guidance (touch
targets, TalkBack). **Flutter performance:** the official "Performance best
practices" and "Rendering performance" pages on docs.flutter.dev (const
constructors, minimise opacity/clipping/`saveLayer`, avoid intrinsics, profile
with DevTools), plus guidance on `RepaintBoundary` and avoiding extra opacity
layers and `BackdropFilter`. **Transit UX evidence:** Watkins et al., "Where Is
My Bus? Impact of mobile real-time information on the perceived and actual wait
time of transit riders", _Transportation Research Part A_ 45(8), 2011 (real-time
information reduces perceived and actual wait); transit apps that label
real-time vs scheduled departures explicitly (animated "waves" for real-time,
greyed times for schedule) and show a "last updated" indicator for stale data;
screen readers should announce arrivals in natural language. **Project
documents:** `AGENTS.md` (rules), `PLAN.md` (architecture, privacy, LGPD,
security, API), `DECISIONS.md` (ADR log).

---

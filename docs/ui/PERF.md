# PERF.md - UI performance baseline (U21)

Date: 2026-10-11. Spec: `docs/ui/UI_SPEC.md` 2.1, 11, 17.4.
Method: same device, same build mode, three runs, median. This host has no
attached Android device, so device rows are TODO for the capable machine.
Commands are listed so the next run reproduces them.

## Baselines

U01 found no stored baseline for the old UI (see `docs/ui/AUDIT.md` 4.1:
cold start, frame times, APK size and memory were never recorded). The
numbers below are therefore the new-UI baseline; UI_SPEC delta budgets
(Android +400 KB, web +120 KB, memory +15 MB) apply from here.

| Metric (UI_SPEC 2.1 / 17.4) | Budget | Measured (this host, release) | Verdict |
| --- | --- | --- | --- |
| Web `main.dart.js` (gz) | delta <= +120 KB | 950 KB gz | new baseline; PLAN 3 MB first-load budget holds (JS path 2.95 MB gz per `docs/field-tests/budgets.md`) |
| Bundled Manrope subset | <= 70 KB | 50.5 KB (`app/assets/fonts/Manrope.ttf`) | inside |
| CanvasKit payload | standard Flutter payload | 36.1 MB uncompressed, cached and compressed in practice | informational |
| Release AAB (arm64-v8a, armeabi-v7a, x86_64, obfuscated) | PLAN <= 15 MB arm64 | 52.3 MB universal | new size baseline; needs the per-ABI split on the capable machine (see below) |
| Cold start to first frame | <= baseline +10 % | TODO device | needs `adb shell am start -W -n com.spotnik.pontual/.MainActivity` |
| Home first-paint to interactive | < 100 ms interaction | TODO device | needs `flutter run --profile --trace-startup` + DevTools |
| Linha open to map visible | paints from cache, no spinner | TODO device | verify no blocking spinner on cached data |
| Map pan frame timings (p50/p95) | p95 build+raster < 8 ms, >= 55 fps >= 90 % frames | TODO device | needs profile mode on hardware |
| Memory after 2 min on Linha | <= baseline +15 MB | TODO device | needs DevTools Memory |
| APK size (`--analyze-size`) | delta <= +400 KB | TODO | `cd app && flutter build apk --release --analyze-size` (refuses multi-ABI; use the AAB per-ABI split) |
| Web transfer (`--analyze-size` equiv) | delta <= +120 KB | TODO | `du -sb build/web` + gzip total; `--analyze-size` does not exist on `flutter build web` in 3.47.6 (see D-U06) |

## Static checks (this host, 2026-10-11)

- Banned widgets: `grep -rn "Opacity(\|BackdropFilter\|ShaderMask\|ColorFiltered\|ImageFiltered" app/lib/ui` finds one `Opacity` in `arrival_row.dart` (past-scheduled dimming) plus a comment mention in `line_map.dart`. No `BackdropFilter`, `ShaderMask`, `ColorFiltered`, `ImageFiltered`. The `Opacity` case is tracked as a U21 fix (dim by colour alpha, not a saveLayer).
- Tickers: `LivePulse` is the single shared pulse controller; it stops on reduced motion or `TickerMode` off. `EtaText` keeps the old child for 140 ms only on value change. No per-marker controllers. Home idle CPU still needs the DevTools check (no pending timers on Inicio).
- Lists: `SliverList.builder` on search and lines; route polyline off (`Features.routeLine` false, manifest `routes` empty).
- Deferred map import on web: missing (AUDIT gap 11). Tracked below.

## TODO for the capable machine (spec 17.4 protocol)

- [ ] Cold start, Home paint, Linha map-visible medians (three runs each).
- [ ] Map pan p50/p95 + memory after 2 min on Linha.
- [ ] Per-ABI AAB/APK sizes + web transfer sizes.
- [ ] Lighthouse accessibility and best-practices >= 95 (U22).
- [ ] Screenshot matrix 17.2 (light/dark x 1.0/2.0) attached to the release PR.

## Fixes from this audit (2026-10-11)

1. Done: `arrival_row.dart` past dimming via colour alpha (no `Opacity`).
2. Decided: deferred map import stays eager (see DECISIONS.md D-U20).
   Revisit with measurements if the web budget regresses.
3. Done: debug-only frame-timing logger (`summarizeBuildRaster` plus
   `installFrameTimingLogger`, hooked in the debug gallery).
4. Done: `docs/ui/PERF.md` created (this file); before/after table fills
   in when device runs land.

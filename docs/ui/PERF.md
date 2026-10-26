# PERF.md - UI performance baseline (U21)

Date: 2026-10-11. Spec: `docs/ui/UI_SPEC.md` 2.1, 11, 17.4.
Method: same device, same build mode, three runs, median. Device runs use `tools/perf/device_run.py`. Results JSON stays gitignored under `tools/perf/results/`; method and medians live here.

## Device runs (2026-10-11)

Device: `sdk_gphone64_x86_64` emulator (Medium_Phone_API_37.0, 1080x2400), SwiftShader software GL, no KVM, profile mode. Software emulation inflates CPU-bound numbers (cold start, raster); build times, PSS and transfer sizes are representative. Hardware re-measurement still wanted for raster p95, battery and field latency.

| Metric (UI_SPEC 2.1 / 17.4) | Budget | Measured | Verdict |
|---|---|---|---|
| Cold start to first frame | <= baseline +10 % (PLAN <= 2 s mid-range) | 2852, 2833, 2911 ms, median 2852 ms (Displayed, force-stop between) | emulator-only; no old-UI baseline exists, so the delta budget has nothing to compare against yet |
| Home idle frames | ~0 %, no ticker | 4 frames in 25 s | PASS by construction (nothing animates without live data) |
| Build p50/p95, line settle (213 frames) | p95 < 8 ms | p50 0.2 ms, p95 7.5 ms | PASS |
| Build p50/p95, line soak with pans (946 frames) | p95 < 8 ms, >= 55 fps >= 90 % frames | p50 0.2 ms, p95 6.8 ms | PASS on build; fps framing needs hardware (see raster note) |
| Raster p50/p95 | p95 < 8 ms | p50 ~130-139 ms, p95 184-813 ms | SwiftShader artifact, not counted; must re-run on hardware |
| Memory after ~2 min on Linha | <= baseline +15 MB (PLAN <= 150 MB map) | 146,672 KB PSS (143.3 MB) | PASS against PLAN; no old-UI baseline for the delta |
| Memory on Home | none set | 124,427 KB PSS (121.5 MB) | recorded as the new baseline |
| arm64 APK | delta <= +400 KB (PLAN universal APK <= 25 MB) | 20,395,264 bytes (19.5 MB); libflutter.so 11.75 MB, libapp.so 7.21 MB, classes.dex 1.49 MB, Manrope 51 KB, line data 8 KB | inside PLAN; delta vs an older AAB below |
| Per-ABI APKs | BigDelta | armeabi-v7a 17.9 MB, arm64-v8a 20.4 MB, x86_64 21.9 MB | recorded |
| Universal AAB | PLAN arm64 <= 15 MB (Play strips per ABI) | 52,337,359 bytes (52.3 MB) with the exact CI flags (`--obfuscate --split-debug-info`); identical to the 52.3 MB D-U16 baseline | delta inside the +400 KB budget |
| Web `main.dart.js` (gz) | delta <= +120 KB (PLAN first load <= 3 MB) | 973,863 bytes gz (951 KB) | new baseline |
| Web first load, Chrome path (gz) | PLAN <= 3 MB | ~3.10 MB (main.dart.js 971 KB + chromium/canvaskit.wasm 2.06 MB + js/fonts/html) | ~3 % over; canvaskit.wasm dominates, same class as the documented wasm overage |
| Screenshots | 17.2 matrix, light/dark x 1.0/2.0 | web desktop/narrow/dark plus device lines/line shots in `tools/perf/results/` | partial; full matrix still wants a phone |

AAB delta note: the 52.3 MB baseline (D-U16) was built with the CI release flags, and the same-flags rebuild of this tree is 52,337,359 bytes (52.3 MB). Delta is inside the +400 KB budget. (A plain release without `--split-debug-info` is 56.1 MB; the debug info is what the flag strips.)

## Baselines (new-UI baseline; delta budgets apply from here)

U01 found no stored baseline for the old UI (cold start, frame times, APK size and memory were never recorded). The numbers below are the new-UI baseline.

| Metric (UI_SPEC 2.1 / 17.4) | Budget | Measured (this host, release) | Verdict |
|---|---|---|---|
| Web `main.dart.js` (gz) | delta <= +120 KB | 950 KB gz | new baseline; PLAN 3 MB first-load budget holds (JS path 2.95 MB gz per `docs/field-tests/budgets.md`) |
| Bundled Manrope subset | <= 70 KB | 50.5 KB (`app/assets/fonts/Manrope.ttf`) | inside |
| CanvasKit payload | standard Flutter payload | 36.1 MB uncompressed, cached and compressed in practice | informational |
| Release AAB (arm64-v8a, armeabi-v7a, x86_64, obfuscated) | PLAN <= 15 MB arm64 | 52.3 MB universal | new size baseline; needs the per-ABI split on the capable machine |
| Cold start to first frame | <= baseline +10 % | TODO device | needs `adb shell am start -W -n com.spotnik.pontual/.MainActivity` |
| Home first-paint to interactive | < 100 ms interaction | TODO device | needs `flutter run --profile --trace-startup` + DevTools |
| Linha open to map visible | paints from cache, no spinner | TODO device | verify no blocking spinner on cached data |
| Map pan frame timings (p50/p95) | p95 build+raster < 8 ms, >= 55 fps >= 90 % frames | TODO device | needs profile mode on hardware |
| Memory after 2 min on Linha | <= baseline +15 MB | TODO device | needs DevTools Memory |
| APK size (`--analyze-size`) | delta <= +400 KB | TODO | `cd app && flutter build apk --release --analyze-size` (refuses multi-ABI; use the AAB per-ABI split) |
| Web transfer (`--analyze-size` equiv) | delta <= +120 KB | TODO | `du -sb build/web` + gzip total; `--analyze-size` does not exist on `flutter build web` in 3.47.6 (see D-U06) |

## Static checks (this host, 2026-10-11)

- Banned widgets: `grep -rn "Opacity(\|BackdropFilter\|ShaderMask\|ColorFiltered\|ImageFiltered" app/lib/ui` finds one `Opacity` in `arrival_row.dart` (past-scheduled dimming, fixed via colour alpha) plus a comment mention in `line_map.dart`. No `BackdropFilter`, `ShaderMask`, `ColorFiltered`, `ImageFiltered`. The `Opacity` case tracked as a U21 fix.
- Tickers: `LivePulse` is the single shared pulse controller; stops on reduced motion or `TickerMode` off. `EtaText` keeps the old child for 140 ms only on value change. No per-marker controllers. Home idle CPU still needs the DevTools check.
- Lists: `SliverList.builder` on search and lines; route polyline off (`Features.routeLine` false, manifest `routes` empty).
- Deferred map import on web: missing (AUDIT gap 11). Tracked below.

## TODO for hardware and field runs (spec 17.4 protocol)

- [ ] Raster p95 + map fps on a real GPU (emulator SwiftShader numbers do not count).
- [ ] Cold start on a mid-range and a low-end phone (emulator: 2852 ms).
- [ ] Battery: leader extra drain <= ~4 %/h, follower <= ~2 %/h (T47).
- [ ] Fix-to-map p95 latency <= 10 s on real phones with riders.
- [ ] Lighthouse accessibility and best-practices >= 95 (no node toolchain on this host).
- [ ] Screenshot matrix 17.2 (light/dark x 1.0/2.0) attached to the release PR; device lines/line plus web desktop/narrow/dark shots exist.

## Fixes from this audit (2026-10-11)

1. Done: `arrival_row.dart` past dimming via colour alpha (no `Opacity`).
2. Decided: deferred map import stays eager (see DECISIONS.md D-U20). Revisit with measurements if the web budget regresses.
3. Done: debug-only frame-timing logger (`summarizeBuildRaster` plus `installFrameTimingLogger`, hooked in the debug gallery).
4. Done: `docs/ui/PERF.md` created (this file); before/after table fills in when device runs land.
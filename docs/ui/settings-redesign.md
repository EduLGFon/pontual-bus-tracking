# Settings redesign: audit and report

Status: implemented (see UI_SPEC 7.8, DECISIONS.md). Full audit, implementation notes and final report removed; only remaining open items are kept.

## Remaining open items (gaps)

- Data saver is consumed only by the line screen list-first map and the viewer-position lookup. It does not change live refresh rate, prefetching or tile preloading.
- Reduce-motion app setting is honoured only where wired in this change (settings switch effective value, `AppMotion` helper, line sheet tab snap). Still ignoring the app setting: router fade-through, `Segmented` thumb, `Pressable` scale/tint, `BannerSlot` size, nav pill tint, timetable rail auto-scroll, skeletons, `LiveDot`/marker interpolation, trip elapsed ticker. `LivePulse` honours the system flag only, not the app setting.
- Cold-start theme flash: a saved non-system theme applies after the first frame, not before.
- Footer version is a compile-time constant, not package info.
- `Report wrong timetable` destination (email, form or tracker): no row added.
- Canonical policy/terms URLs and support contact (INFRA-23): unchanged.
- Whether the footer version should switch to package info (adds an async lookup or a new dependency) or stay a compile-time constant.

## Decisions retained

- Ripple vs tint: kept `Pressable` tint plus scale; rows meet the 56 dp target and single-switch semantics.
- Shared `SectionHeader` untouched; settings uses its own small muted header.
- Theme flash kept (PLAN 8.4, first paint never waits).
- Reduce-motion storage: old bool key stays readable; unset means follow system.
- Clear-data scope: clears favorites, recents, shortcuts, alerts, kudos, onboarding and install-hint flags, and the static/remote caches. Keeps theme, motion and data-saver settings, consent record, device token and the live trip.
- Footer version stays the `appVersion` compile-time constant.
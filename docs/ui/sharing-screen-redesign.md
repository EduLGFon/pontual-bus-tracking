# Sharing screen redesign

Status: implemented (see UI_SPEC 7.7, DECISIONS.md). Full audit, implementation notes and final report removed; only remaining open items are kept.

## Remaining open items (gaps)

1. Web minimized trips lose protection: disposing `TripScreen` disables `ProdWebWakeLock` and cancels the visibility timer while the controller keeps running in the host. Reopening re-acquires. No leak on start, stop, error, dispose.
2. No per-trip direction stored (`lineLabel` is the line name); the chip lists both endpoints instead of a live sense.
3. Reopened screen reads the controller synchronously (no stale flash), except the line badge which waits on `linesProvider`.
4. Every main screen shows sharing through `LiveDockHost` plus the Settings sharing banner; verified in code and by the minimize widget test, not by hand on a device.

## Recommendations (out of scope)

- Foreground service with persistent notification so the phone can lock during the trip (Android already uses the geolocator foreground service; the tip discount stays until then).
- Auto-stop after long inactivity or far-from-route.
- Adaptive update frequency.
- The skipped dim view can be revisited with measured numbers.

## Needs owner input

- Confirm the three new thresholds (weak 30 m, stale 45 s, low battery 15 %).
- Route geometry and stop coordinates (shared with line detail): `data/routes/` still empty.
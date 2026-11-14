# Personal arrival at the rider's stop

Status: implemented 2026-11-10 (Flutter client, tests only, no device/field run); placement updated 2026-11-11 for UX 2.0; viewer location auto-request and 60 s refresh added 2026-11-13. See D96 and D116.

## Goal

On the line screen, answer "when will a bus reach my stop?":

- Rider opts in with one tap.
- App snaps rider to nearest learned stop of that line, within 300 m.
- App calls existing `GET /v1/lines/:id/eta?stop=<id>`.
- Sheet shows next bus ETA with certainty, confidence and stop distance.
- Map shows chosen stop; vehicle list shows each bus ETA to the stop.
- Missing data degrades honestly; no invented number.

Non-goals: routing, geocoding, stop picker, push notifications, background location, sending coordinates, changing learning subsystem, changing ETA endpoint contract.

## Data path

1. `viewerFixProvider` (`NotifierProvider<ViewerFixController, ViewerFixState>`): automatic foreground request on first open of a pilot line (one attempt, recorded in local pref `viewer_location_auto_requested_v1`), status, position, accuracy, timestamp; explicit rider taps (including the map focus-on-viewer control) can retry or force an immediate fix.
2. `viewerLocationProvider`: `FutureProvider<LatLng?>` derived from fix state; compatibility seam for `line_screen.dart` and `reports_adapter.dart`.
3. `learnedStopsProvider(lineId)`: existing, returns line direction-0 learned stops.
4. `etaProvider((lineId, stopId))`: existing, calls server ETA endpoint. Refreshed by invalidation at most every 10 s while line screen visible and not in data saver. No timer/poll loop; reuses existing `vehicleTickProvider` (5 s, pauses off-foreground).
5. Viewer fix refresh: while the line screen is open and the app is resumed and data saver is off, the fix refreshes at most every 60 s on the existing 5 s vehicle tick (no new timer, no position stream, no background location). The map focus-on-viewer control forces a fresh fix immediately, recenters immediately and again after the new fix lands, and resets the 60 s window. An in-flight refresh keeps the previous position visible; a silent failure keeps the old fix until the existing 5 minute staleness rule; a refresh never prompts.
6. `personalArrivalProvider(lineId)`: composes fix, stops, vehicles and ETA into one `PersonalArrivalVM`.
7. Pure logic in `ui/adapters/personal_arrival.dart`: nearest stop, ETA mapping, approach filter, formatting. Unit tested with no widgets.

Server ETA uses line active learned route and stops (direction 0). Client uses same stop list. Direction 1 buses may appear: keep only `Certainty.live` vehicles and filter vehicles whose heading points away from stop (bearing diff > 90 degrees). Stopped vehicles (speed < 1.5 km/h or unknown heading) are kept.

Only line id and stop id are sent. Coordinates never leave the device.

## Privacy

- One automatic foreground request on first open of a pilot line; the reusable OS/browser permission prompt is the only first-use permission UI. The in-app pre-permission privacy sheet is no longer on the normal path.
- After a denial, automatic attempts never prompt again; a later attempt may silently reuse a grant made in system settings; explicit rider taps can retry.
- Foreground only. No `getPositionStream`, no watcher, no background permission, no wake lock for location.
- Native precise-only with 120 m gate; web 200 m gate.
- No persistence, logging or sending of coordinates.
- Fix is refreshed at most every 60 s while the line screen is open and the app is resumed and data saver is off; an in-flight refresh keeps the previous position visible and a silent failure keeps the old fix until the existing 5 minute staleness rule.
- `viewerLocationProvider` no longer auto-prompts on web; it derives from the fix state.

## Honesty rules

- Only `Certainty.live` vehicles get an ETA.
- Heading filter for opposite-direction buses.
- Passed and approaching distinction.
- Arriving only when ETA <= 60 s or within 120 m with ETA <= 180 s.
- No fake number.
- Walking time is estimate from straight-line distance at 80 m per minute (minimum 1 minute); never presented as a route.
- Leave-now verdict derived from ETA and walk estimate, never separate source.
- Server confidence (high/medium/low) and sample count shown.
- Stale fix after 5 minutes asks to refresh; no ETA shown for expired fix.

## State table

| State | Visible copy key | Behavior |
|---|---|---|
| locating | `myStopLoading` | Automatic foreground fix in flight; shows the existing loading copy instead of the opt-in prompt. |
| needsLocation | `myStopEnable` / `myStopPrivacy` | Compact prompt above tabs with title, opt-in body and "Ver quando chega no meu ponto"; tapping opens the recovery sheet after a denied or failed automatic attempt. |
| loadingStops | `myStopLoading` | Fix ready, learned stops still loading. |
| noStops | `myStopNoStops` | Fix ready, line has no learned stops. Honest muted card. |
| noStopNear | `myStopNoStopNear` | Fix ready, no learned stop within 300 m. Honest muted card. |
| noLive | (none) | Fix ready, stops ready, no live vehicle. Standard timetable hero stays; card renders nothing. |
| etaLoading | `myStopCalculating` | Live bus exists, ETA request in flight. |
| ready | `myStopTitle` / `myStopNearby` + `myStopEta` | Hero above tabs. Live bus has valid ETA. Lead bus = smallest `eta_s` among approaching buses. Carries walking estimate and leave-now verdict. |
| noApproaching | `myStopNoApproaching` | Live buses exist but none has valid approach/ETA. |
| etaError | `myStopNoEstimate` | ETA request failed or returned null. Show "Sem previsão agora" plus refresh. |

Stop title: "Seu ponto" when distance <= 120 m, else "Ponto mais próximo".

## UI placement

- Personal card is hero above tabs when ready; replaces standard next-bus hero, so one hero. Not a card inside Agora tab.
- Compact prompt above tabs while location is off: "Quanto tempo até meu ponto?" plus body and "Ver quando chega no meu ponto" ghost link. Tapping opens privacy sheet; OS/browser prompt only follows "Usar minha localização" tap.
- Header no longer carries personal summary label ("No seu ponto, ~N min"). Hero owns ETA; header keeps only line status line.
- Walking estimate under ETA: "≈N min a pé", straight-line distance at 80 m per minute, minimum 1 minute for any positive distance.
- Leave-now verdict under estimate: "Saia agora", "Saia em ≈N min", "Ainda dá tempo", "Chegando ao seu ponto" or "O ônibus está no ponto", each with one-line hint. Leave now when ETA not longer than walk; leave soon when difference up to 3 minutes; otherwise spare time. Arriving and at-stop win over walk comparison.
- Every time presented as estimate: ≈ prefix and "Como calculamos" sheet state walk is straight-line distance, not a route.
- Map marker: distinct "Seu ponto" marker at chosen stop, primary fill, surface ring, onPrimary inner dot, never a bus and never pulsing.
- Per-row ETA in vehicle list.
- "Como calculamos" sheet with `myStopInfoBody`, walk estimate note and sample count sentence.
- Compact sheets keep 270 dp peek minimum (raised from 220 dp) so header plus hero ETA fit at 320x568; sheet still snaps to half and full. Medium and expanded side panels (360/400 dp) use same hero without drag handle.

## Battery, performance and accessibility

- One automatic foreground fix on first open; refresh at most every 60 s on the existing 5 s vehicle tick while the line screen is open and the app is resumed and data saver is off. No new timer, no position stream, no background location.
- Pauses off-route and in data saver.
- One sentence per card and row.
- Separate action nodes.
- 200% text: no fixed-height card; everything wraps or scales down without clipping.

## Testing

Unit, card, map, location, row and flow test files:

- `app/test/ui/personal_arrival_logic_test.dart`
- `app/test/ui/personal_arrival_card_test.dart`
- `app/test/ui/my_stop_map_test.dart`
- `app/test/ui/viewer_fix_test.dart`
- `app/test/ui/vehicle_row_test.dart`
- `app/test/ui/personal_arrival_flow_test.dart`
- `app/test/ui/line_screen_test.dart`

Full suite result: `flutter test` in `app/` passed, 610 tests, 1 skipped. No device or field verification.

## Limitations

- Direction-0 learned route and stops on server; no learned stops means no personal ETA.
- Precise-only excludes approximate grants.
- No push notification.
- Fix refreshes at most every 60 s while the line screen is open and the app is resumed and data saver is off; a locating state shows the existing loading copy. The fix is stale after 5 minutes and then asks to refresh.
- Map marker is decorative for screen readers because map has one summary label and card carries sentence.
- No device or field verification.

## Acceptance criteria

- `dart format --output=none --set-exit-if-changed lib test` in `app/` is clean.
- `flutter analyze` in `app/` is clean.
- `flutter test` in `app/` is green.
- No new dependency in `pubspec.yaml` or `pubspec.lock`.
- No server, schema or API contract change.
- No coordinate logged, persisted or sent.
- On first open of a pilot line, one automatic foreground fix request occurs; the reusable OS/browser permission prompt is the only first-use permission UI. After a denial automatic attempts never prompt again; explicit rider taps can retry.
- The first pilot-line open makes the automatic foreground request; after a denial automatic attempts do not prompt again; explicit rider taps retry and the error recovery sheet remains available.
- With granted precise fix and learned stops, card shows "Seu ponto"/"Ponto mais próximo" with ETA, confidence and stop distance.
- With no stops, no live bus, no approach or ETA failure, card shows matching honest state and never fake number.
- Map shows chosen stop with distinct marker; vehicle rows carry personal ETA labels.
- 200% text and reduced motion do not clip or animate unexpectedly.
- Screen readers get one sentence per card and row.

## References

- DECISIONS.md D96
- docs/ui/UI_SPEC.md 7.5
- AGENTS.md sections 8 and 15

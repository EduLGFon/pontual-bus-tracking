# Personal arrival at the rider's stop

Status: implemented 2026-11-10, Flutter client, tests only (no device or field run).

## Goal

On the line screen, answer "when will a bus reach my stop?" for the rider:

- The rider opts in with one tap.
- The app snaps the rider to the nearest learned stop of that line, within 300 m.
- The app calls the existing `GET /v1/lines/:id/eta?stop=<id>` endpoint.
- The sheet shows the next bus ETA to that stop, with certainty, confidence, and the stop distance.
- The map shows the chosen stop; the vehicle list shows each bus ETA to the stop.
- If anything is missing, the UI degrades honestly and never invents a number.

Non-goals: routing, geocoding, stop picker, push notifications, background location, sending coordinates to the server, changing the learning subsystem, changing the ETA endpoint contract.

## Data path

1. `viewerFixProvider` (`NotifierProvider<ViewerFixController, ViewerFixState>`): explicit request, status, position, accuracy, timestamp.
2. `viewerLocationProvider`: `FutureProvider<LatLng?>` derived from the fix state, kept as a compatibility seam for `line_screen.dart` and `reports_adapter.dart`.
3. `learnedStopsProvider(lineId)`: existing, returns the line's direction-0 learned stops.
4. `etaProvider((lineId, stopId))`: existing, calls the server ETA endpoint. Refreshed by invalidation at most every 10 s while the line screen is visible and not in data saver. No timer, no poll loop: reuses the existing `vehicleTickProvider` (5 s, pauses off-foreground).
5. `personalArrivalProvider(lineId)`: composes the fix, stops, vehicles, and ETA into one `PersonalArrivalVM`.
6. Pure logic in `ui/adapters/personal_arrival.dart`: nearest stop, ETA mapping, approach filter, formatting. Unit tested with no widgets.

The server ETA endpoint uses the line's active learned route and stops (direction 0). The client uses the same stop list. Direction 1 buses may appear in the response: the client keeps only vehicles with `Certainty.live` and filters out vehicles whose heading points away from the stop (bearing difference > 90 degrees). Stopped vehicles (speed < 1.5 km/h or unknown heading) are kept.

Only the line id and stop id are sent. Coordinates never leave the device.

## Privacy

- Tap only. No location request on mount.
- Foreground one-shot. No `getPositionStream`, no watcher, no background permission, no wake lock.
- Native precise-only with the 120 m gate; web 200 m gate.
- No persistence, no logging, no sending of coordinates.
- Fix reused for 5 minutes within the app session; after that the card asks to refresh.
- `viewerLocationProvider` no longer auto-prompts on web; it derives from the explicit fix.

## Honesty rules

- Only `Certainty.live` vehicles get an ETA.
- Heading filter for opposite-direction buses.
- Passed and approaching distinction.
- Arriving only when ETA <= 60 s or within 120 m with ETA <= 180 s.
- No fake number.
- Server confidence (high/medium/low) and sample count shown.
- Stale fix after 5 minutes asks to refresh; no ETA shown for an expired fix.

## State table

| State | Visible copy key | Behavior |
|---|---|---|
| needsLocation | `myStopEnable` / `myStopPrivacy` | Compact prompt with "Ver quando chega no meu ponto" and the privacy line. |
| loadingStops | `myStopLoading` | Fix ready, learned stops still loading. |
| noStops | `myStopNoStops` | Fix ready, the line has no learned stops. Honest muted card. |
| noStopNear | `myStopNoStopNear` | Fix ready, no learned stop within 300 m. Honest muted card. |
| noLive | (none) | Fix ready, stops ready, no live vehicle. Standard timetable hero stays; card renders nothing. |
| etaLoading | `myStopCalculating` | A live bus exists, ETA request in flight. |
| ready | `myStopTitle` / `myStopNearby` + `myStopEta` | A live bus has a valid ETA. Lead bus = smallest `eta_s` among approaching buses. |
| noApproaching | `myStopNoApproaching` | Live buses exist but none has a valid approach/ETA. |
| etaError | `myStopNoEstimate` | ETA request failed or returned null. Show "Sem previsão agora" plus refresh. |

Stop title: "Seu ponto" when distance <= 120 m, else "Ponto mais próximo".

## UI placement

- Header summary at peek: when ready, replace the timetable next-departure row with a ghost link "No seu ponto, ~N min" (or "chegando"). Tapping it snaps the sheet to half and selects Agora.
- Card in the Agora tab.
- Card replaces the standard hero when ready (one hero per screen).
- Map marker: distinct "Seu ponto" marker at the chosen stop, primary fill, surface ring, onPrimary inner dot, never a bus and never pulsing.
- Per-row ETA in the vehicle list.
- "Como calculamos" sheet with `myStopInfoBody` plus the sample count sentence.

## Battery, performance and accessibility

- One fix, no timer, throttle at most every 10 s on the existing 5 s vehicle tick.
- Pauses off-route and in data saver.
- One sentence per card and row.
- Separate action nodes.
- 200 percent text: no fixed-height card; everything wraps or scales down without clipping.

## Testing

Unit, card, map, location, row and flow test files:

- `app/test/ui/personal_arrival_logic_test.dart`
- `app/test/ui/personal_arrival_card_test.dart`
- `app/test/ui/my_stop_map_test.dart`
- `app/test/ui/viewer_fix_test.dart`
- `app/test/ui/vehicle_row_test.dart`
- `app/test/ui/personal_arrival_flow_test.dart`
- `app/test/ui/line_screen_test.dart`

Full suite result: `flutter test` in `app/` passed, 514 tests, 1 skipped. No device or field measurements were taken.

## Limitations

- Direction-0 learned route and stops on the server; no learned stops means no personal ETA.
- Precise-only excludes approximate grants.
- No push notification.
- Fix is one-shot and stale after 5 minutes.
- The map marker is decorative for screen readers because the map has one summary label and the card carries the sentence.
- No device or field verification.

## Acceptance criteria

- `dart format --output=none --set-exit-if-changed lib test` in `app/` is clean.
- `flutter analyze` in `app/` is clean.
- `flutter test` in `app/` is green.
- No new dependency in `pubspec.yaml` or `pubspec.lock`.
- No server, schema, or API contract change.
- No coordinate is logged, persisted, or sent.
- The line screen shows "Ver quando chega no meu ponto" before any location request.
- Tapping the prompt opens the privacy sheet; the OS or browser prompt only follows the "Usar minha localização" tap.
- With a granted precise fix and learned stops, the card shows "Seu ponto"/"Ponto mais próximo" with an ETA, confidence, and the stop distance.
- With no stops, no live bus, no approach, or an ETA failure, the card shows the matching honest state and never a fake number.
- The map shows the chosen stop with a distinct marker; the vehicle rows carry the personal ETA labels.
- 200 percent text and reduced motion do not clip or animate unexpectedly.
- Screen readers get one sentence per card and row.

## References

- DECISIONS.md D96
- docs/ui/UI_SPEC.md 7.5
- AGENTS.md sections 8 and 15
# Stops and the stop sheet

Design for the global stop layer and the stop sheet on the line screen. See
`DECISIONS.md#D124`, `ARCHITECTURE.md` 4.1/6.5 and `UI_SPEC.md` 7.5/13.6.

## Purpose

Let a rider see every known stop on any line map and, at street zoom, tap one
to learn which lines serve it and when the next bus is expected. The sheet
separates a fixed timetable departure from a live prediction and never
presents one as the other. It also never presents a terminal departure as an
exact passage time at that stop.

## Entry and map layer

- Every line map, including timetable-only lines, draws all globally known
  stops from `allStopsProvider` (`GET /v1/stops`), not only the current
  line's learned stops.
- The visual dot stays 10 dp. Only at map max zoom 17 (`mapMaxZoom`) does
  the marker get a 48 dp tappable target and button semantics. Below zoom 17
  the dots remain visible but are not tappable because 48 dp hit boxes
  overlap for stops 50 m apart.
- All stops are still drawn. There is no silent cap and no partial list.
- At that zoom, tapping a stop opens a modal stop sheet. Reports keep their own
  path: a coarse ~150 m area, never a stop picker (D83).

## Sheet content and states

The title is the stop name when the data provides one; learned stops currently
carry no name, so the fallback title `Ponto de ônibus` is used. One row per
distinct line serving the stop shows the line badge and name, then two clearly
separate blocks.

Fixed block:

- Label `Tabela (saída do terminal)`, then up to two terminal departure times
  from the static timetable. These are terminal departures, not stop passage
  times.
- `Sem horários cadastrados` when the line has no schedules at all for that
  day. `Sem mais saídas hoje` when schedules exist but none remain today.

Live block:

- Label `Previsão`. The best eligible live prediction for that line shows
  `Agora` only for a real estimate at <= 60 seconds, otherwise `~N min`.
- `Sem previsão ao vivo` when no live vehicle is approaching.
- `Não foi possível atualizar` on a fetch failure; the next open or tick
  retries.
- A small inline progress indicator while the first arrivals request is
  loading.

Other states:

- No distinct line known: `Nenhuma linha conhecida neste ponto`.
- Unknown stop or learning disabled (`404 not_found`): no predictions.
- Loading, empty and failure states are explicit; the sheet never fabricates
  a time.
- `passed` and the 0-second non-`learned` sentinels are hidden because neither
  is a real approaching bus. Those sentinels include `fallback` and
  `fallback_distance`; only a zero-second `learned` estimate counts as a real
  prediction.

Refresh: on open and at most every 15 s while the sheet is open, driven by the
existing vehicle tick. No new polling timer. A non-empty global stops network
result is kept for the app lifetime; a static fallback after a 404 or failure
is not kept and is retried on a later line-screen mount.

## Privacy

Stop positions are public transport infrastructure and learned aggregates.
The client sends only the opaque stop id on `GET /v1/stops/:id/arrivals`; it
sends no coordinates, device id or trip identity, and the sheet adds no new
personal data. No raw trip trace is exposed; member stop ids are part of the
aggregate stop contract.

## Tests

Coverage targets, run with `flutter test` from `app/`:

- `test/global_stop_test.dart`: defensive parsing and validity bounds.
- `test/learning_repository_stops_test.dart`: both endpoint mappings and 404
  handling.
- `test/all_stops_provider_test.dart`: non-empty caching and failure/empty
  retry behavior.
- `test/ui/stop_sheet_test.dart`: fixed versus predicted copy, hidden
  `passed`/`fallback`, loading, empty and failure states.
- `test/ui/my_stop_map_test.dart` and `test/route_direction_test.dart`: map
  layers stay compatible with the new stop type and arrow spacing.

No test result is claimed by this document.

## Known limits

- Fixed times are terminal departures, not exact stop passage. A bus can
  reach the stop later than the terminal departure time.
- A live prediction is an estimate, not a tracked countdown. It depends on
  live vehicle coverage and learned route geometry; `fallback_distance` is a
  straight-line estimate with low confidence.
- The global stop list can be large. Stops stay visible at city zoom but are
  only tappable at map max zoom 17 (`mapMaxZoom`); 48 dp hit boxes overlap at
  lower zoom.
- The merged stop id is the smallest member stop id. It is stable while
  membership is unchanged but can change when stops merge or split.
- With learning disabled both endpoints return 404. The bundle has no line
  refs for those stops, so the sheet shows no known lines; timetable data
  remains available elsewhere in the app.

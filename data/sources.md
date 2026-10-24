# Data sources

Every `source_ids` entry in `data/lines/*.json` must be listed here with its
URL, retrieval date, and licence or permission status. Timetables are
transcribed manually and sparingly from public sources. Never scrape sources
that forbid it. Times are unofficial and can change without notice; the app
shows an "unofficial timetable" notice.

## Sources

- `owner-test` - Internal owner field-testing line (id 99). Not a real
  operator line; used so test trips do not pollute learned aggregates of
  real lines. No public source; maintained by the owner.

- `onibus-online` - Onibus Online, Viação São Gabriel company page and
  per-line timetable pages. Retrieved 2026-10-03. Third-party aggregator
  claiming official collection, updated 2026. Informational use only.
  Company page: <https://onibus.online/empresas/viacao-sao-gabriel/>
  (states 21 urban lines). Line names for all 21 lines transcribed from
  that page. Pilot timetables (60, 62, 64, 66) transcribed from the
  per-line detail pages the same day.

## Caveats (VERIFY against the operator or SGBus app before release)

- Embedded itinerary digits on the source pages were stripped; only plain
  departure times were kept. A duplicated 13:20 on line 66 Centro and
  duplicated 23:00 on line 60 Litorâneo were collapsed to one each.
- Line 62 split into two pilot lines: 62 "Guriri / Ifes-Ufes via BR-101"
  (keeps the transcribed timetable) and 63 "Guriri / Ifes-Ufes via Jacuí"
  (timetable pending). Line 21 has a separate operator variant
  "Santo Antônio x Aviação via Jacuí" that is not yet split (candidate).
  Line 66 carries internal itinerary variants (via Rodonaldo/Centro) under
  one line number and is intentionally not split.
- Operator site lists two different lines as "Linha 013"; kept as published
  (10 Aroeira / Morada do Ribeirão, 13 Aroeira / Cohab).
- Lines 62 and 66 show weekday times only on the source; 41 shows
  Sunday/holiday only. Unknown whether that reflects operation or gaps.
- Non-pilot lines carry names only; their timetables are pending.
- Route geometry is pending owner field traces (T17).

## Stops

- `osm-stops` - OpenStreetMap bus-stop nodes (`highway=bus_stop`,
  `public_transport=platform`) inside the served area, retrieved
  2026-10-13 via the Overpass API and stored as `data/stops.json`.
  ODbL licence; attribution is shown in-app (map chip and About).
  12 stops total: 8 near the center (6 unnamed, 2 named
  "Ponto de ônibus") plus 4 the first seed missed although they
  predate it - `Guriri` (named, served by the Guriri lines),
  2x `Entrada do Jaguaré` (intermunicipal corridor), and one unnamed
  stop on the northern coastal corridor. Full coverage still needs an
  owner field survey, like route geometry (T17).
  `public_transport=stop_position` nodes (on-road stopping points,
  not waiting places) were excluded.
  Re-checked 2026-10-20 via the OSM API for the same 12 node ids: only
  `Guriri`, `Entrada do Jaguaré` (two nodes) and the generic
  "Ponto de ônibus" (two nodes) have names; seven nodes have no
  `name`. No new posted names were found, so none were invented.
  A field survey is still needed for the unnamed stops; reports no longer depend on them (D83).
- Other sources checked 2026-10-13, none usable for coordinates:
  the operator site lists street itineraries only (no coordinates);
  the Prefeitura page links to the SGBus app; onibus.online lists
  street itineraries; SGBus (Mobilibus/Bus2 white-label) shows stops
  in-app but exposes no public API or open data; Google Maps and
  Moovit data are proprietary (Moovit scraping is also a repo hard
  limit). No GTFS feed exists for Sao Mateus. Do not copy
  coordinates from any of these; map new stops into OSM during the
  field survey instead.
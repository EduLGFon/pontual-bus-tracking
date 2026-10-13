# Data sources

Every `source_ids` entry in `data/lines/*.json` must be listed here with its
URL, retrieval date, and licence or permission status. Timetables are
transcribed manually and sparingly from public sources. Never scrape sources
that forbid it. Times are unofficial and can change without notice; the app
shows an "unofficial timetable" notice.

## Sources

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
- Line 62 runs as one line id; its via João XXIII and via BR-101 variants
  are not split (owner pattern "via Jacui" not found on the source page).
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
  Only 8 stops are mapped in OSM for the whole city, all near the
  center; full coverage needs an owner field survey, like route
  geometry (T17). `public_transport=stop_position` nodes (on-road
  stopping points, not waiting places) were excluded.
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
  (no separate page on the source; timetable pending). Line 21 has a separate operator variant
  "Santo Antônio x Aviação via Jacuí" that is not yet split (candidate).
  Line 66 carries internal itinerary variants (via Rodonaldo/Centro) under
  one line number and is intentionally not split.
- Operator site lists two different lines as "Linha 013"; kept as published
  (10 Aroeira / Morada do Ribeirão, 13 Aroeira / Cohab).
- Lines 62 and 66 show weekday times only on the source; 41 shows
  Sunday/holiday only. Unknown whether that reflects operation or gaps.
- Non-pilot lines now carry transcribed timetables from onibus.online (retrieved 2026-10-26); still unofficial (VERIFY before release).
- Route geometry is pending owner field traces (T17).

## Stops

- Stops are no longer shipped from internet/OSM data. All bus stop points are
  learned from trip data (aggregated, anonymized). `data/stops.json` is empty.
  See PLAN.md (stops learned from trips) and the privacy rules: no raw
  location at rest.
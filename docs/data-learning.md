# Data Learning: Route, Stops, Dwell, and ETA

Status: implemented in 0.3.x, enabled by default (`learning_enabled`). v2 rework
(DECISIONS.md#D109) replaced the gated, process-local model with DB-backed
accumulators; every organic trip from a consenting, non-opted-out device
contributes. Legal sign-off and final consent wording remain release gates.

Companions: ARCHITECTURE.md (5.5, 6, 7, 12, 13); DECISIONS.md (D02, D20, D30, D46,
D98, D109); docs/privacy/inventory.md; docs/privacy/ripd.md. Scope tags per
ARCHITECTURE.md 0.2: [A] alpha, [A*] alpha should, [L] later.

## 0. Purpose

Pontual serves live positions from rider pings plus static timetables and
hand-recorded route polylines. This subsystem lets crowd-sourced trips teach:
driven way-path per line/direction as a polyline with a sample-trip count;
stops actually served with cumulative dwell distributions by 15-minute bucket
and day of week; ETA prediction from current pace plus historic segment and
stop data.

Deliberately light: no ML framework, no per-fix DB writes, no raw track
storage, no new runtime beyond the existing Deno API process.

Goals: learn a centerline polyline per line/direction with sample-trip count;
detect stops from repeated low-speed dwells, cluster into stable points with
stable id + ordinal; store cumulative dwell/segment travel histograms by
15-min bucket + day of week plus derived p50/p90 and count; produce ETA
predictions; keep the privacy contract (no raw fixes, device/trip ids, client
timestamps, trimmed trip ends, aggregate-only centroids, consent + opt-out).

Non-goals: turn-by-turn/point-to-point routing (ARCHITECTURE.md 1.2); per-vehicle or
per-driver profiling; third-party traffic; separate ML serving cluster in alpha
(ARCHITECTURE.md 5.5); replacing static timetable (D07); learning from anything but
accepted fixes from consenting riders (no scraping/operator feeds, ARCHITECTURE.md 7.5).

Success criteria: a trip covering >=2 grid cells publishes a route labelled
`trips: 1`; with >=5 trips/direction, median distance to a hand-recorded route
(where one exists) < 40 m; stop precision/recall >= 0.8 on labelled stops on
two active lines; ETA MAE at 5-min horizon < 90 s on a held-out simulator week;
prediction endpoints add < 5 ms p99 to snapshot build; no per-fix DB write;
privacy audit: no raw coordinate, device id, or trip id in any table, log, or
metric; route/stop centroids are cross-trip aggregate means.

## 1. Privacy and legal gate (D20)

Release gate. Consent version 2 and inventory update shipped; lawyer/DPO review
and final RIPD sign-off pending.

1. Consent text v2 shipped (de-identified aggregate derivation; old consent
   valid for live sharing only).
2. RIPD update (purpose, aggregate inventory, retention, re-identification risk):
   pending legal sign-off.
3. Data inventory of every new table/field: shipped (docs/privacy/inventory.md).
4. Lawyer review of consent wording and aggregate schema: pending.
5. Opt-out: server flag and `DELETE /v1/me/learning` exist; privacy center
   exposes one-way "stop contributing". No re-enable path; copy says so.

Hard rules (ARCHITECTURE.md 8, 15):
- No raw per-trip tracks, ever. Only grid cells, stop centroids, aggregate
  histograms.
- Trim first/last `trimEndsS` (default 120) s of every trip. A trip shorter
  than 2 * trimEndsS is trimmed by at most 10% per end; if that leaves < 2
  fixes, all fixes used. Short trips are not dropped.
- No device/trip/session id or client timestamp in any aggregate row or event
  payload consumed here.
- No eligibility gate: a trip with >= 2 kept fixes contributes after consent +
  opt-out checks, regardless of prior trip count. Confidence is the row's sample
  count, not a permission.
- `synthetic` field on `POST /v1/trip` defaults false, client-supplied and
  untrusted, can only suppress that trip's learning contribution; never grants
  access, changes live sharing, or is persisted. Simulator sets it (D110).
- Day/hour buckets come from the event being aggregated in America/Sao_Paulo
  (UTC-3): dwell uses its own start, segment uses destination arrival. Trip
  start is never reused for every sample.
- Aggregates keyed by line, direction, segment/stop, time bucket only - never
  by rider.
- Retention: stop with no pass for 90 days deactivated; inactive stop deleted
  after another 90 days, cascading bins/stats; retired routes deleted after 30
  days; route cells/edges kept while line+direction exist.

## 2. Architecture

```
Trip sharing (ping.ts / tick.ts) -> EngineEvent bus
  -> LearningConsumer (in-process): per-trip working state in memory
  -> async per-trip contribution queue (trip-end order)
  -> PostgreSQL aggregates (route cells/edges/state, learned stops, dwell/travel
     bins, stop/segment stats, learned routes)
  -> HTTP reads indexed aggregate tables -> Flutter client (route, stops, ETA,
     place search)
```

Key properties:
- `domain/` stays pure/sync; emits events, never imports learning module.
- Consumer is stateful subscriber in server layer (`server/src/learning/`).
- PostgreSQL is source of truth; in-memory `routeAccs`/`stopClusters` maps are
  mirrors for direction assignment + proximity matching; reloaded on startup.
- Finalized trip writes stops/bins/derived stats in one transaction; route
  cells/edges/state follow in separate parameterized statements, then route
  rebuilt from PostgreSQL and published.
- Contribution + publication run off request path in a serialized in-memory
  queue (trip-end order); never block HTTP response. A queued-but-unstarted
  contribution lost on process death; no raw trip persisted for replay.
- Periodic flush (`learning_flush_interval_s`, default 300) drains queue and
  republishes any direction whose stored sample count is ahead of its active
  route: crash-window safety net, not publication trigger.
- Serving queries aggregate tables directly; responses carry HTTP cache headers;
  no separate read-model cache.
- No new dependency, runtime, database, or Deno permission.

## 3. Event contract

`EngineEvent` learning variants:

```ts
type EngineEvent =
  | { kind: "vehicleUpdated"; lineId: number }
  | { kind: "tripEnded"; lineId: number; tripKey: string; reason: EndReason }
  | { kind: "tripStarted"; lineId: number; tripKey: string; startedAtMs: number; lat: number; lng: number; synthetic?: boolean }
  | { kind: "fixAccepted"; lineId: number; tripKey: string; atMs: number; lat: number; lng: number; speedMps: number; heading: number | null; accuracyM: number }
  | { kind: "vehicleRemoved"; lineId: number; vehicleId: number };
```

Emission (ping.ts / tick.ts): `startTrip` emits `tripStarted` with first fix,
`tripKey` a fresh random UUID held only in consumer's working map; `applyPing`
accepted fix emits `fixAccepted`; `endTrip` emits `tripEnded` with `tripKey`;
`startTrip` copies optional `synthetic` flag into event. Consumer ignores
synthetic trips. `tripKey` never leaves process or is logged. `fixAccepted`
emitted for every accepted fix; consumer downsamples to at most one sample per
`minSampleSpacingM` (default 20 m) of travel or `minSampleSpacingS` (default 10
s), whichever first.

## 4. Aggregation model

### 4.1 In-memory working state (per trip, discarded on end)

`TripWork`: tripKey, lineId, direction (assigned at end), consentVersion,
startedAtMs, endedAtMs, samples[], dwells[], totalDistanceM.

Rules: if consentVersion < minConsentVersion (default 2), consumer ignores trip
(defensive; live-sharing guard already rejects outdated consent). Opt-out
checked before events reach consumer; opted-out device creates no working state.
No per-device trip-count gate. Samples capped at maxSamplesPerTrip (default 200);
excess uniformly downsampled. Trip ends trimmed per section 1. Working state
dropped on trip end, failure, process exit, or restart.

### 4.2 Persisted accumulators

- `learning_route_cells` / `learning_route_edges`: one row per visited grid cell
  / directed cell transition per line+direction, with `trips` counter and
  weighted centroid for cells. A cell counts contributing trips, not fixes.
- `learning_route_state`: cumulative `sample_trips` per line+direction plus
  `last_publish_at`.
- `learned_stops`: stable stop ids, centroids, radius, `sample_passes`, active
  flag, ordinal.
- `learning_dwell_bins` / `learning_travel_bins`: cumulative histograms keyed by
  stop or segment, 15-min bucket, day of week, 5-s duration bin.
- `stop_dwell_stats` / `segment_stats`: derived p50/p90 and sample counts,
  recomputed from all retained bins for affected keys.
- `learned_routes`: versioned published polylines with `sample_trips` and median
  deviation.

Grid origin fixed near Sao Mateus (lat -18.72, lng -39.85), so cell keys survive
restarts/processes. No accumulator exists only in memory.

### 4.3 Direction assignment

Collect line's route accumulators from mirror (reloaded from PostgreSQL).
- No accumulator: direction 0.
- One accumulator: that accumulator's direction (restart that reloaded one slot
  keeps new trips on it instead of splitting corridor into direction 0).
- Two accumulators: higher `coverageScore` against kept fixes wins. If both cover
  nothing, compare trip's first-to-last bearing with each accumulator chain,
  pick closer. If bearing uncomputable, direction 0.
- Never more than 2 directions per line. Active learned routes seed direction
  slots on startup.

### 4.4 Consent, opt-out, test data

Trip handler looks up device opt-out flag and passes current consent version.
Failed lookup contributes nothing (fail closed). Synthetic trip ignored by
consumer before any working state, so no cells/stops/bins/stats.

## 5. Algorithms

### 5.1 Route learning (absolute corridor)

Input: kept fixes for one completed trip.

Step 1, per-trip filtering: trim ends, then require >= 2 kept fixes. No
minimum trip distance or progress normalisation; partial trips keep real
position. A fix-to-fix gap > 500 m (`DEFAULT_MAX_GAP_M`) splits the segment;
trip still contributes cells/edges actually covered.

Step 2, absolute accumulation: temporary accumulator uses fixed grid origin and
`corridorCellM` (default 50 m). Each visited cell and directed transition
deduplicated per trip, then upserted with `trips = trips + 1`. Cell centroids
are running weighted means across trips. `learning_route_state.sample_trips`
incremented once per contributing trip+direction.

Step 3, chain building (after every contributing trip): rebuild accumulator
from PostgreSQL; walk directed cell graph from in-degree-0 nodes (all nodes when
cycle), always taking highest-weight edge. Ties prefer straightest
continuation, then stable key. Require >= 2 cells and some edge weight. No
minimum trip count, cell-count gate, or polyline length. Apply 3-point moving
average, then Douglas-Peucker at 5 m; if > 400 points, retry at 10 m. Encode
polyline precision 5. Reject publication when encoded string > 8192 chars; keep
active geometry, update confidence.

Step 4, versioning: compute `medianDeviationM` between new polyline and active
one. If < 15 m, update active row's `sample_trips` + `computed_at` in place
(controls version churn, not eligibility). Otherwise retire active version and
insert new active row with `sample_trips` from `learning_route_state`. Retired
rows deleted after 30 days. After publication, project stop centroids onto new
chain and persist ordinals (stops created by same trip already in `learned_stops`
get ordinal on this publication).

Cold start: no static route and no active learned route -> line has no polyline,
client draws nothing.

### 5.2 Stop detection and clustering

Per trip: dwell = maximal run with speed < `stopSpeedMps` (default 1.0 m/s) for
>= `minDwellS` (default 5 s). Record centroid + duration. Dwells not surviving
end trim ignored.

Cross-trip: match dwell to existing stop for same line+direction within
`stopClusterRadiusM` (default 30 m), first in trip's working set, then startup
cache. No match: insert new stop on first dwell (no minimum pass/distinct-day
gate). Match: update centroid as weighted mean against row's own
`sample_passes`, increment `sample_passes`, set `last_seen_at` and
`active = true`. Stop ids are server-side UUIDs, never derived from location.

### 5.3 Dwell histograms

Bucket each dwell by its own start: 15-min `hour_bucket` (0..95), `day_of_week`
(0..6) in America/Sao_Paulo, duration bin
`bin_s = clamp(round(durationS / 5) * 5, 5, 3600)`. Upsert
`learning_dwell_bins` for (stop, hour, day, bin) with `sample_count + 1`.
Recompute `stop_dwell_stats` for affected (stop, hour, day) keys from all
retained bins: `sample_count` = sum of bin counts; p50/p90 nearest-rank over
histogram. No per-batch reservoir or last-batch overwrite. Serving returns any
row with >= 1 sample with its count. No `kMin`, distinct-day, or terminus
suppression.

### 5.4 Segment travel histograms

Consecutive dwells at distinct stops form a segment. Travel time =
`to.startMs - from.endMs`; distance = haversine between stop centroids. Bucket
by destination arrival timestamp, not trip start. Upsert `learning_travel_bins`
for (line, direction, from, to, hour, day, bin) with `sample_count + 1`, then
recompute `segment_stats` from all retained bins like dwell stats.

### 5.5 ETA prediction

For vehicle + target downstream stop S:
1. Snap vehicle to active polyline (or static route); compute progress p (0..1)
   using cumulative along-route distance from the snapped vehicle position. No
   route -> return a parameterised straight-line fallback at
   `learning_default_speed_mps`, low confidence, method `fallback_distance`;
   never a fake zero or `passed`.
2. Find next stop at progress > p.
3. Remaining stops = next stop to S inclusive.
4. For each remaining segment, look up `segment_stats` for (line, direction,
   from, to, hour, day). If no exact bucket, try same hour any day, then
   `distance / defaultSpeedMps`. Base time = p50 of chosen row. Adjust by
   current pace: `factor = clamp(histSpeed / currentSpeed, 0.5, 2.0)`, where
   `histSpeed = distance / baseTime`. Pace below about 1.5 m/s is treated as
   stopped and priced at `learning_default_speed_mps` instead of dividing
   distance by a clamped 1 m/s pace; `currentSpeed` uses that rule. Add dwell
   p50 for following stop, or `defaultDwellS`.
5. Add partial time from vehicle position to next stop using cumulative
   along-route distance from the snapped vehicle position to the next stop, not
   only the remainder of one polyline segment, at current speed, capped at twice
   historic segment rate.
6. `passed` requires route geometry and the vehicle clearly past the target,
   with a 30 m tolerance.
7. Return `{ etaS, confidence, sampleCount, method }`. Confidence reflects data
   coverage: `high` when every bucket found, `medium` for 1-2 defaults, `low`
   for > 2 defaults. `sampleCount` = sum of counts of rows used. Method
   `learned` remains for the normal path. Segment and dwell stats, sample counts
   and confidence tiers remain.

Predictions computed on demand in predictor.ts, never stored.

### 5.6 Serving and update cadence

- Route publication: after every contributing trip, in async queue. No trip-count
  trigger or weekly recompute.
- Stats: recomputed from bins for affected keys inside trip transaction.
- Flush: every `flushIntervalS` (default 300 s) drains queue and republishes
  stale routes (crash-window safety net).
- Reads: direct indexed queries. HTTP cache headers (300 s learned route/stops/
  bulk index; 10 s ETA).
- All contribution work best effort; failure counted + logged without
  coordinates; live sharing unaffected.

## 6. Persistence schema

Migrations: `0003_learning.sql` creates `learned_routes`, `learned_stops`,
`segment_stats`, `stop_dwell_stats`, old `learning_watermarks`.
`0004` adds retention indexes. `0006_learning_accumulators.sql` adds DB-backed
accumulators and removes obsolete eligibility/watermark tables.

Tables (0006):
- `learning_route_cells(line_id, direction, cell_key, lat, lng, trips,
  first_seen_at, last_seen_at)` PK (line_id, direction, cell_key).
- `learning_route_edges(line_id, direction, from_cell, to_cell, trips,
  first_seen_at, last_seen_at)` PK (line_id, direction, from_cell, to_cell).
- `learning_route_state(line_id, direction, sample_trips, last_publish_at)` PK
  (line_id, direction).
- `learning_dwell_bins(stop_id FK cascade, hour_bucket, day_of_week, bin_s,
  sample_count)` PK (stop_id, hour_bucket, day_of_week, bin_s).
- `learning_travel_bins(line_id, direction, from_stop FK cascade, to_stop FK
  cascade, hour_bucket, day_of_week, bin_s, sample_count)` PK (...).
- `learning_watermarks` dropped; `devices.learning_trips` dropped.

`pontual_app` gets select/insert/update/delete on every new table. Down
migration restores old shells.

Notes: `learned_stops.lat/lng` and `learning_route_cells.lat/lng` are aggregate
centroids - the only location at rest introduced here, cross-trip means. No
device/trip/client-timestamp/speed/heading/accuracy/battery column in any
aggregate. Bins cascade from `learned_stops`; route cells/edges reference no
stop or device. `no_location_at_rest` test allows exactly those columns.

## 7. Serving API

Public reads (no auth), consistent with vehicle reads (ARCHITECTURE.md 6.5). Rate
limits per IP.

### 7.1 `GET /v1/lines/:id/learned-route`

```json
{ "v": 3, "dir": 0, "polyline": "_p~iF~ps|U...", "points": null, "trips": 47, "computed_at": "2026-10-20T12:00:00Z", "fallback": false }
```
`v` = learned_routes.version; `trips` = sample_trips. No active learned route:
200 with `fallback: true` and static route polyline when line has one, else
`polyline: null`. `points` reserved, currently null. `Cache-Control: public,
max-age=300`. Rate limit 60/min/IP.

### 7.2 `GET /v1/lines/:id/stops`

```json
{ "dir": 0, "stops": [ { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 } ], "fallback": false }
```
`i` = ordinal along published route; `n` = sample_passes. Without learned route,
direction = one with more learned stops. No learned stops: 200 with `stops: []`,
`fallback: true`. No static stop fallback in server response. Cache 300 s.

### 7.3 `GET /v1/lines/:id/eta`

Query: `stop` (uuid, required), optional `vehicle` (vehicle id from snapshot).
Without `vehicle`, returns ETAs for all live vehicles on the line.

```json
{ "stop": "uuid", "now": 1730000000, "items": [ { "vehicle": 12, "eta_s": 240, "conf": "high", "n": 38 } ], "next_scheduled_s": null }
```
`next_scheduled_s` reserved, currently null; client uses timetable directly.
Computed on demand, 10 s cache header. Rate limit 120/min/IP.

### 7.4 `GET /v1/learned-routes?bbox=latMin,lngMin,latMax,lngMax`

Bulk index for place search. Active learned routes with stops for lines whose
polyline or stops intersect optional bbox. Cache 300 s.

### 7.5 Client data flow

`LearningRepository` (`app/lib/data/learning/`) fetches learned route, stops,
ETA, bulk index over HTTP with 8 s timeout. Map draws learned polyline when
present, else static route, else nothing. Place search uses bulk index and
degrades to no results on 404/failure. Personal-arrival card requests ETA for
snapped stop; only line + stop ids sent; viewer position stays on device.

## 8. Client changes summary

- Repository: `app/lib/data/learning/learning_repository.dart`.
- Domain models: `LearnedRoute`, `LearnedStop`, `LearnedRoutesIndex`,
  `EtaEstimate` in `app/lib/domain/learning/`.
- Map, place search, personal arrival consume those models.
- Privacy center calls `DELETE /v1/me/learning` from confirmed "stop
  contributing" action; one-way, reports offline honestly.
- No change to trip sharing, battery, or foreground service. `TripController`
  remains the only place that starts/stops the service.

## 9. Configuration and tunables

Runtime values in `app_config`; defaults compiled in. Keys read by
`server/src/learning/config.ts`:

| Key | Default | Meaning |
| --- | --- | --- |
| `learning_enabled` | `true` | master switch |
| `learning_min_consent_version` | `2` | min consent version for contribution |
| `learning_trim_ends_s` | `120` | seconds trimmed from each trip end |
| `learning_flush_interval_s` | `300` | safety-net flush period |
| `learning_corridor_cell_m` | `50` | absolute corridor grid cell size (m) |
| `learning_stop_cluster_radius_m` | `30` | stop matching radius (m) |
| `learning_stop_speed_mps` | `1.0` | dwell speed threshold |
| `learning_min_dwell_s` | `5` | min dwell duration (s) |
| `learning_default_speed_mps` | `6` | fallback speed |
| `learning_default_dwell_s` | `20` | fallback dwell (s) |

`learning_corridor_cell_m` is a geometry invariant for existing accumulators.
Changing it in place would reinterpret stored cell keys at the new size. Before
changing, truncate `learning_route_cells`, `learning_route_edges`,
`learning_route_state` for affected lines and let them re-learn. Same applies to
compiled grid origin.

Removed in v2: `learning_min_route_trips`, `learning_min_trip_route_m`,
`learning_min_stop_passes`, `learning_k_min`, `learning_cache_ttl_s`,
`learning_headway_horizon_s`, `learning_recompute_every_n_trips`,
`stopMinDistinctDays`, `corridorMinCells`, `minRouteLengthM`, and
`LEARNING_PRIVACY_MODE` (with `route_stops` mode). Code ignores these keys if
they remain in an old `app_config` row.

Client-side fallback constants mirror these where needed; server value always
wins (ARCHITECTURE.md 7).

## 10. Privacy controls

- No k-anonymity gate. Routes, stops, dwell stats, segment stats published and
  served from first sample. Every served row carries sample count; client can
  present low-confidence estimates honestly.
- Accepted tradeoff: one consenting rider's trip can shape a route, stop
  centroid, or histogram bucket. Remaining controls: consent, opt-out, end
  trimming, aggregate-only storage, no device/trip ids, no raw tracks. Lawyer +
  DPO sign-off required before public release.
- Previous 5-trip device gate, `kMin`, distinct-days suppression,
  `minStopPasses`, terminus dwell suppression removed. They were eligibility and
  serving gates, not ingestion filtering.
- Distinct-trip counting no longer uses a salted per-flush hash (no
  distinct-trip gate remains).
- Stop centroids are weighted means across passes; route cell centroids weighted
  means across contributing trips. Neither stores an individual fix.
- Logs use existing `Log` wrapper (no API accepting coordinates). Learning
  metrics are counters only: trips contributed, flushes, flush failures,
  direction assignments, trips with long gap, no-cell transitions, route
  publications, retirements, oversized routes, chain-too-small, no-flap
  suppressions. No coordinates, ids, or per-line counts.
- `no_location_at_rest` test scans every migration and rejects location-like
  columns outside `learned_stops` and `learning_route_cells`.
- Synthetic/test traffic excluded via optional `synthetic` flag. Flag not
  persisted and has no security effect; a real rider could use it to skip one
  trip's contribution (equivalent to per-trip opt-out).

## 11. Retention and deletion

- Aggregates cumulative. Stop with no pass for 90 days marked inactive;
  inactive stop deleted when last pass older than 180 days. `learning_dwell_bins`,
  `learning_travel_bins`, `stop_dwell_stats`, `segment_stats` cascade with stop.
- `learned_routes`: retired rows deleted after 30 days; active rows stay until
  replaced.
- `learning_route_cells` / `learning_route_edges`: kept while line+direction exist
  (published route rebuilt from them). Size bounded by fixed grid + line count.
- `learning_route_state`: kept with route.
- `DELETE /v1/me` cascades device row incl. `learning_opt_out`. No aggregate row
  references a device.
- `DELETE /v1/me/learning` sets opt-out flag; future trips do not contribute.
  Privacy center exposes as confirmed one-way action. A trip already in progress
  can finish contributing. Past aggregates not recomputed (cannot be attributed).
- Earlier rolling 90-day stat deletion replaced by stop lifecycle. Cumulative
  histograms have no per-trip timestamps, so deleting only derived stat row while
  bins remained would not delete underlying data. Deviation recorded in D109;
  needs legal review.

## 12. Performance and resource budgets

- No per-fix DB writes. Trip end triggers one transaction for stops/bins/stats
  plus cell/edge/state statements plus one route publish.
- Working state bounded by maxSamplesPerTrip (200) per active trip, dropped at
  trip end. Global memory cap not enforced in this version.
- Contribution + publication in serialized async queue, not request path. Slow DB
  delays learning, not live sharing.
- Reads are indexed queries on aggregate keys. HTTP cache headers absorb repeat
  reads.
- Histogram size bounded by stops x 96 hour buckets x 7 days x distinct 5-s
  duration bins observed. Monitor `learning_dwell_bins` / `learning_travel_bins`
  growth in production.
- Deno permissions unchanged: no new write/run/ffi.

## 13. Testing strategy

Unit (Deno, pure functions, no DB):
- `learning_corridor_test.ts`: partial trips form one chain, opposite
  directions stay separate, gap handling, simplification, size budget.
- `learning_test.ts`: fake SQL exercising first-trip publication, cumulative
  bins, single dwell + segment, two samples in one bucket, per-event midnight
  bucketing, short trips surviving trim, stop ordinals, synthetic-trip exclusion.
- `trip_schema_test.ts`: optional `synthetic` field accepted as boolean,
  rejected otherwise.
- `learning_eligibility_test.ts`: every consenting non-opted-out trip accepted;
  old consent and opt-out contribute nothing.
- `learning_retention_test.ts`: purge deactivates/deletes dormant stops, never
  deletes stats while bins remain.
- `no_location_at_rest_test.ts`: migration column allow-list.
- `config_test.ts`, `metrics_test.ts`: removed env/config + counter behavior.

Integration (vs PostgreSQL 18.6, existing security suite):
- Migrations 0001-0006 apply cleanly; 0006 down rolls back and reapplies.
- Full server suite passes with `TEST_DATABASE_URL`: 136 passed, 0 failed.
- Flush writes only aggregate rows; no raw fix columns.
- Consent, opt-out, synthetic paths do not write aggregates.
- A row with one sample is served; no withholding gate.

Privacy audit: grep learning files for coordinate logging (CI check); migration
column allow-list per table.

## 14. Status

Implemented in 0.3.x: event plumbing, corridor learning, stop detection,
cumulative dwell + segment histograms, ETA prediction, learned-route
persistence, client seams, server opt-out endpoint. `learning_enabled` defaults
to true.

D109 (2026-11-12) replaced the 5-trip eligibility gate, `devices.learning_trips`,
`learning_min_route_trips`, `corridorMinCells`, `minRouteLengthM`,
`minStopPasses`, `kMin`, distinct-days suppression and `LEARNING_PRIVACY_MODE`
with DB-backed accumulators and single-sample serving. See ADR for accepted risk
and evidence.

Remaining before release: lawyer/DPO sign-off and RIPD finalisation. Privacy
center exposes one-way stop-contributing action; no re-enable path.

## 15. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| One trip shapes route/stop/histogram | Re-identification of rider's trip | Consent, opt-out, trimming, no ids, legal review; label sample counts in UI |
| Simulator traffic reaches production | Fake aggregates | Simulator sends `synthetic: true`; server ignores those trips for learning without changing live sharing |
| Long-lived cumulative bins | Growing storage/retained history | Stop lifecycle retention (90 days inactive, 180 days total); monitor table growth |
| Route changes (construction, detours) | Stale polyline | Replaced once median deviation > 15 m; keep static route as fallback |
| Direction misclassification on circular lines | Mixed samples corrupt chain | Two directions/line, coverage then bearing; single direction for circulars not automatic |
| Database unavailable | Learning stops | Live sharing continues; failures counted and retried by later trips |
| Process dies before queued contribution | One trip lost | DB keeps prior accumulators; no raw trip stored for replay |
| Oversized polyline | No new version | 8192-char cap; keep active geometry, update confidence |
| Migration risk on production | Downtime | Forward-only; test on staging; owner runs migration per runbook |

## 16. Decisions

Decided: opt-out default on (ADR 2026-10-26); learned route auto-replaces
static geometry when published; every organic trip contributes; DB-backed
accumulators; single-sample serving; 15 m median-deviation version churn
control; stop-lifecycle retention (D109).

Still open: public ETA exposure, max directions per line (2 recommended), a
re-enable path if owner decides opt-out must be reversible, separate
model-serving process (defer until CPU budget requires), true rolling window if
legal review requires.
</content>
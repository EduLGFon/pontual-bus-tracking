# Data Learning Plan: Route, Stops, Dwell, and ETA

Status: implemented in 0.3.x and enabled by default (`learning_enabled`). The
v2 rework (DECISIONS.md#D109) replaced the gated, process-local model with
DB-backed accumulators. Every organic trip from a consenting, non-opted-out
device contributes. Legal sign-off and final consent wording remain release
gates.

Companions: PLAN.md (5.5, 6, 7, 12, 13); DECISIONS.md (D02, D20, D30, D46,
D98, D109); docs/privacy/inventory.md; docs/privacy/ripd.md.

Scope tags follow PLAN.md 0.2: [A] alpha, [A*] alpha should, [L] later. The
learning subsystem shipped in 0.3.x; remaining work is legal sign-off, a real
PostgreSQL migration run, and tuning.

## 0. Purpose and status

Pontual serves live vehicle positions from rider pings plus static timetables
and hand-recorded route polylines where available. This subsystem lets
crowd-sourced trips teach the system: the driven way-path per line as a
polyline; stops actually served with cumulative dwell distributions by time of
day and day of week; real ETA prediction from current pace plus historic
segment and stop data.

Deliberately light: no ML framework, no per-fix DB writes, no raw track
storage, no new runtime beyond the existing Deno API process.

Goals:
- Learn a centerline polyline per line and direction from accepted trip fixes,
  with a sample-trip count served with the geometry.
- Detect stops from repeated low-speed dwells, cluster into stable stop points,
  and assign a stable id and ordinal along the route.
- Store cumulative dwell and segment travel histograms by 15-minute bucket and
  day of week, plus the derived p50/p90 and sample count.
- Produce ETA predictions for a vehicle to downstream stops from current
  position, current pace, and historic segment and stop stats.
- Keep the privacy contract: no raw fixes, no device or trip ids, no client
  timestamps, trimmed trip ends, aggregate-only centroids, consent and opt-out.

Non-goals: turn-by-turn navigation or point-to-point routing (PLAN.md 1.2);
exact per-vehicle or per-driver profiling; third-party traffic; a separate ML
serving cluster in the alpha (PLAN.md 5.5); replacing the static timetable
(timetables stay static JSON, D07); learning from any source other than
accepted fixes from consenting riders (no scraping or operator feeds,
PLAN.md 7.5).

Success criteria:
- A contributing trip that covers at least two grid cells publishes a route
  labelled with `trips: 1`. With at least 5 trips in a direction, the median
  distance to a hand-recorded route (where one exists) is under 40 m.
- Stop detection precision and recall are at least 0.8 on manually labelled
  stops on two active lines.
- ETA median absolute error at a 5-minute horizon is under 90 s on a held-out
  week of simulator trips.
- The prediction endpoints add less than 5 ms p99 to snapshot build time, and
  there is no per-fix database write.
- Privacy audit: no raw coordinate, device id, or trip id in any table, log
  line, or metric. Route and stop centroids are cross-trip aggregate means.

## 1. Privacy and legal gate (D20)

Release gate. Consent version 2 and the inventory update are shipped;
lawyer/DPO review and final RIPD sign-off remain pending.

1. Consent text version bump to 2: shipped. It covers de-identified aggregate
   derivation; old consent remains valid for live sharing only.
2. RIPD update covering the new purpose, aggregate inventory, retention and
   re-identification risk: pending legal sign-off.
3. Data inventory listing every new table and field: shipped
   (`docs/privacy/inventory.md`).
4. Lawyer review of consent wording and aggregate schema: pending.
5. Opt-out: the server flag and `DELETE /v1/me/learning` endpoint exist. The
   privacy center exposes a one-way "stop contributing" action. There is no
   re-enable path in the app; the copy says so.

Hard rules (PLAN.md 8 and 15):
- No raw per-trip tracks, ever. Only grid cells, stop centroids and aggregate
  histograms are written.
- Trim first and last `trimEndsS` (default 120) seconds of every trip before
  aggregation. A trip shorter than 2 * `trimEndsS` is trimmed by at most 10% per
  end; if that leaves fewer than 2 fixes, all fixes are used. Short trips are
  not dropped for being short.
- No device id, trip id, session id, or client timestamp in any aggregate row
  or in the event payload consumed by this subsystem.
- There is no eligibility gate. A trip with at least two kept fixes contributes
  after consent and opt-out checks, regardless of how many trips the device
  shared before. Confidence is the sample count attached to a row, not a
  permission.
- Synthetic test traffic is marked by the optional `synthetic` field on
  `POST /v1/trip`. It defaults to false, is client-supplied and untrusted, and
  can only suppress that trip's learning contribution. It never grants access,
  changes live sharing, or is persisted. The simulator sets it. See D110.
- Day and hour buckets come from the event being aggregated, in
  America/Sao_Paulo (UTC-3): a dwell uses its own start, a segment uses the
  destination arrival. The trip start is never reused for every sample.
- Aggregates are keyed by line, direction, segment or stop, and time bucket
  only. Never by rider.
- Retention follows the learned-stop lifecycle: a stop with no pass for 90 days
  is deactivated, and an inactive stop is deleted after another 90 days,
  cascading its bins and stats. Retired routes are deleted after 30 days. Route
  cells and edges are kept while the line and direction exist.

## 2. High-level architecture

```
Trip sharing (existing): ping.ts / tick.ts
  -> EngineEvent bus
  -> LearningConsumer (in-process): per-trip working state in memory
  -> async per-trip contribution queue (trip-end order)
  -> PostgreSQL aggregates: learning_route_cells, learning_route_edges,
     learning_route_state, learned_stops, learning_dwell_bins,
     learning_travel_bins, stop_dwell_stats, segment_stats, learned_routes
  -> HTTP reads query indexed aggregate tables
  -> Flutter client (route, stops, ETA, place search)
```

Key properties:
- `domain/` stays pure and synchronous. It emits events and never imports the
  learning module.
- The consumer is a stateful subscriber in the server layer
  (`server/src/learning/`).
- PostgreSQL is the source of truth. The in-memory `routeAccs` and
  `stopClusters` maps are mirrors used only for direction assignment and
  proximity matching. Startup reloads them from the aggregate tables.
- A finalized trip writes stops, bins and derived stats in one transaction.
  Route cells, edges and state follow in separate parameterized statements,
  then the route is rebuilt from PostgreSQL and published.
- Contribution and publication run off the request path in a serialized
  in-memory queue, so they keep trip-end order and never block the HTTP
  response. A contribution queued but not started when the process dies is
  lost. No raw trip is persisted for replay.
- The periodic flush (`learning_flush_interval_s`, default 300) drains the
  queue and republishes any direction whose stored sample count is ahead of its
  active route. It is a crash-window safety net, not the publication trigger.
- Serving queries the aggregate tables directly. Responses carry HTTP cache
  headers; there is no separate read-model cache.
- No new dependency, runtime, database, or Deno permission.

## 3. Event contract

`EngineEvent` carries the learning variants:

```ts
type EngineEvent =
  | { kind: "vehicleUpdated"; lineId: number }
  | { kind: "tripEnded"; lineId: number; tripKey: string; reason: EndReason }
  | { kind: "tripStarted"; lineId: number; tripKey: string; startedAtMs: number; lat: number; lng: number; synthetic?: boolean }
  | { kind: "fixAccepted"; lineId: number; tripKey: string; atMs: number; lat: number; lng: number; speedMps: number; heading: number | null; accuracyM: number }
  | { kind: "vehicleRemoved"; lineId: number; vehicleId: number };
```

Emission points (in `ping.ts` / `tick.ts`):
- `startTrip`: emit `tripStarted` with the first fix. `tripKey` is a fresh
  random UUID generated in the server layer and held only in the consumer's
  working map.
- `applyPing` accepted fix: emit `fixAccepted`.
- `endTrip`: emit `tripEnded` with `tripKey`; the consumer finalizes and
  removes the working state.
- `startTrip` copies the optional `synthetic` request flag into the event. The
  consumer ignores the trip when it is true. The flag is never persisted.

Privacy: `tripKey` never leaves the process and is never logged. It exists only
to correlate fixes within one trip in memory.

Throttling: `fixAccepted` is emitted for every accepted fix. The consumer
downsamples to at most one sample per `minSampleSpacingM` (default 20 m) of
travel or `minSampleSpacingS` (default 10 s), whichever comes first.

## 4. Aggregation model

### 4.1 In-memory working state (per trip, discarded on end)

```ts
interface TripWork {
  tripKey: string;
  lineId: number;
  direction: number | null; // assigned at end
  consentVersion: number;
  startedAtMs: number;
  endedAtMs: number | null;
  samples: Array<{ t: number; lat: number; lng: number; speed: number }>;
  dwells: Array<{ lat: number; lng: number; startMs: number; endMs: number }>;
  totalDistanceM: number;
}
```

Rules:
- If `consentVersion < minConsentVersion` (default 2), the consumer ignores the
  trip. The live-sharing guard already rejects an outdated consent, so this is
  a defensive check.
- Opt-out is checked before the events are handed to the consumer; an
  opted-out device creates no working state.
- There is no per-device trip-count gate. A first trip is treated exactly like
  a thousandth trip.
- Samples are capped at `maxSamplesPerTrip` (default 200); excess is uniformly
  downsampled.
- Trip ends are trimmed as described in section 1.
- Working state is dropped on trip end, failure, process exit, or restart.

### 4.2 Persisted accumulators

- `learning_route_cells` and `learning_route_edges`: one row per visited grid
  cell or directed cell transition per line and direction, with a `trips`
  counter and a weighted centroid for cells. A cell counts contributing trips,
  not fixes.
- `learning_route_state`: cumulative `sample_trips` per line and direction,
  plus `last_publish_at`.
- `learned_stops`: stable stop ids, centroids, radius, `sample_passes`, active
  flag and ordinal.
- `learning_dwell_bins` and `learning_travel_bins`: cumulative histograms keyed
  by stop or segment, 15-minute bucket, day of week, and 5-second duration bin.
- `stop_dwell_stats` and `segment_stats`: derived p50/p90 and sample counts,
  recomputed from all retained bins for the affected keys.
- `learned_routes`: versioned published polylines with `sample_trips` and
  median deviation.

The grid origin is fixed near Sao Mateus (`lat -18.72`, `lng -39.85`), so cell
keys survive restarts and processes. No accumulator exists only in memory.

### 4.3 Direction assignment

- Collect the line's route accumulators from the mirror, which is reloaded
  from PostgreSQL.
- No accumulator: direction 0. One accumulator: that accumulator's direction,
  so a restart that reloaded one slot keeps new trips on it instead of
  splitting the corridor into direction 0.
- Two accumulators: the higher `coverageScore` against the kept fixes wins.
  If both cover nothing, compare the trip's first-to-last bearing with each
  accumulator chain and pick the closer one. If a bearing cannot be computed,
  use direction 0.
- Never create more than 2 directions per line. Active learned routes seed
  direction slots on startup.

### 4.4 Consent, opt-out and test data

The trip handler looks up the device's opt-out flag and passes the current
consent version. A failed lookup contributes nothing (fail closed). A synthetic
trip is ignored by the consumer before any working state is created, so it
contributes no cells, stops, bins or statistics.

## 5. Algorithms

### 5.1 Route learning (absolute corridor)

Input: kept fixes for one completed trip.

Step 1, per-trip filtering:
- Trim the ends, then require at least 2 kept fixes. There is no minimum trip
  distance and no progress normalisation; partial trips keep their real
  position.
- A fix-to-fix gap over 500 m (`DEFAULT_MAX_GAP_M`) splits the segment. The trip
  still contributes the cells and edges it actually covered.

Step 2, absolute accumulation:
- A temporary accumulator uses the fixed grid origin and `corridorCellM`
  (default 50 m). Each visited cell and each directed transition is deduplicated
  for the trip, then upserted with `trips = trips + 1`.
- Cell centroids are running weighted means across trips, never a single fix.
- `learning_route_state.sample_trips` is incremented once per contributing
  trip and direction.

Step 3, chain building (after every contributing trip):
- Rebuild the accumulator from PostgreSQL and walk the directed cell graph from
  nodes with in-degree 0 (all nodes when the graph is a cycle), always taking
  the highest-weight edge. Ties prefer the straightest continuation, then a
  stable key.
- Require at least 2 cells and some edge weight. There is no minimum trip count,
  cell-count publication gate, or minimum polyline length.
- Apply a 3-point moving average, then Douglas-Peucker at 5 m. If the result has
  more than 400 points, retry at 10 m.
- Encode with polyline precision 5. Reject publication when the encoded string
  exceeds 8192 characters and keep the active geometry, while updating its
  confidence.

Step 4, versioning:
- Compute `medianDeviationM` between the new polyline and the active one. If it
  is below 15 m, update the active row's `sample_trips` and `computed_at` in
  place. This controls version churn; it is not an eligibility gate.
- Otherwise retire the active version and insert a new active row with
  `sample_trips` from `learning_route_state`. Retired rows are deleted after
  30 days.
- After publication, project stop centroids onto the new chain and persist
  their ordinals. Stops created by the same trip are already in
  `learned_stops` and get their ordinal on this publication.

Cold start: if there is no static route and no active learned route, the line
has no polyline and the client draws nothing.

### 5.2 Stop detection and clustering

Per trip: a dwell is a maximal run with speed below `stopSpeedMps` (default
1.0 m/s) for at least `minDwellS` (default 5 s). Record its centroid and
duration. Dwells that do not survive the end trim are ignored.

Cross-trip:
- Match a dwell to an existing stop for the same line and direction within
  `stopClusterRadiusM` (default 30 m), first in this trip's working set, then in
  the startup cache.
- No match: insert a new stop on the first dwell. There is no minimum pass or
  distinct-day gate.
- Match: update the centroid as a weighted mean against the row's own
  `sample_passes`, increment `sample_passes`, set `last_seen_at` and
  `active = true`.
- Stop ids are server-side UUIDs, never derived from location.

### 5.3 Dwell histograms

- Bucket each dwell by its own start timestamp: 15-minute `hour_bucket`
  (0..95), `day_of_week` (0..6) in America/Sao_Paulo, and a duration bin
  `bin_s = clamp(round(durationS / 5) * 5, 5, 3600)`.
- Upsert `learning_dwell_bins` for (stop, hour, day, bin) with
  `sample_count + 1`.
- Recompute `stop_dwell_stats` for affected (stop, hour, day) keys from all
  retained bins: `sample_count` is the sum of bin counts; p50 and p90 are
  nearest-rank values over the histogram. There is no per-batch reservoir and
  no last-batch overwrite.
- Serving returns any row with at least one sample, together with its count.
  There is no `kMin`, distinct-day, or terminus suppression.

### 5.4 Segment travel histograms

- Consecutive dwells at distinct stops form a segment. Travel time is
  `to.startMs - from.endMs`; distance is the haversine distance between the two
  stop centroids.
- Bucket the segment by the destination arrival timestamp, not the trip start.
- Upsert `learning_travel_bins` for (line, direction, from, to, hour, day, bin)
  with `sample_count + 1`, then recompute `segment_stats` from all retained
  bins in the same way as dwell stats.

### 5.5 ETA prediction

For a vehicle and target downstream stop S:
1. Snap the vehicle to the active polyline (or static route). Compute progress
   p (0..1). If there is no route, fall back to straight-line distance divided
   by the assumed speed.
2. Find the next stop at progress greater than p.
3. Remaining stops are those from the next stop to S inclusive.
4. For each remaining segment, look up `segment_stats` for (line, direction,
   from, to, hour, day). If there is no exact bucket, try the same hour with any
   day, then fall back to `distance / defaultSpeedMps`. Base time is the p50 of
   the chosen row. Adjust by current pace:
   `factor = clamp(histSpeed / currentSpeed, 0.5, 2.0)`, where
   `histSpeed = distance / baseTime` and `currentSpeed = max(vehicle.paceMps, 1)`.
   Add the dwell p50 for the following stop, or `defaultDwellS`.
5. Add the partial time from the vehicle position to the next stop at the
   current speed, capped at twice the historic segment rate.
6. Return `{ etaS, confidence, sampleCount, method }`. Confidence reflects data
   coverage, not a privacy threshold: `high` when every bucket was found,
   `medium` for one or two defaults, `low` for more than two defaults.
   `sampleCount` is the sum of the counts of the rows used.

Predictions are computed on demand in `predictor.ts` and are never stored.

### 5.6 Serving and update cadence

- Route publication: after every contributing trip, in the async queue. There
  is no trip-count trigger and no weekly recompute job.
- Stats: recomputed from bins for affected keys inside the trip transaction.
- Flush: every `flushIntervalS` (default 300 s) drains the queue and
  republishes stale routes as a crash-window safety net.
- Reads: direct indexed queries. HTTP responses use cache headers (300 s for
  learned route, stops and bulk index; 10 s for ETA).
- All contribution work is best effort. A failure is counted and logged
  without coordinates; live sharing is unaffected.

## 6. Persistence schema

Migration `server/db/migrations/0003_learning.sql` creates `learned_routes`,
`learned_stops`, `segment_stats`, `stop_dwell_stats` and the old
`learning_watermarks`. Migration `0004` adds retention indexes. Migration
`0006_learning_accumulators.sql` adds the DB-backed accumulators and removes the
obsolete eligibility and watermark tables:

```sql
-- 0006 summary, forward-only
create table learning_route_cells (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  cell_key text not null,
  lat double precision not null,
  lng double precision not null,
  trips integer not null default 0 check (trips >= 0),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (line_id, direction, cell_key)
);

create table learning_route_edges (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  from_cell text not null,
  to_cell text not null,
  trips integer not null default 0 check (trips >= 0),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (line_id, direction, from_cell, to_cell)
);

create table learning_route_state (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  sample_trips integer not null default 0 check (sample_trips >= 0),
  last_publish_at timestamptz,
  primary key (line_id, direction)
);

create table learning_dwell_bins (
  stop_id uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  bin_s smallint not null check (bin_s >= 0),
  sample_count integer not null default 0 check (sample_count >= 0),
  primary key (stop_id, hour_bucket, day_of_week, bin_s)
);

create table learning_travel_bins (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  from_stop uuid not null references learned_stops(id) on delete cascade,
  to_stop uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  bin_s smallint not null check (bin_s >= 0),
  sample_count integer not null default 0 check (sample_count >= 0),
  primary key (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week, bin_s)
);

drop table if exists learning_watermarks;
alter table devices drop column if exists learning_trips;
```

The down migration restores the old shells. `pontual_app` receives
select/insert/update/delete on every new table.

Notes:
- `learned_stops.lat/lng` and `learning_route_cells.lat/lng` are aggregate
  centroids. They are the only location at rest introduced by this subsystem,
  and they are cross-trip means, not individual fixes. The
  `no_location_at_rest` test allows exactly these columns and keeps rejecting
  everything else.
- No device id, trip id, client timestamp, speed, heading, accuracy or battery
  column exists in any aggregate table.
- Bins cascade from `learned_stops`. Route cells and edges do not reference a
  stop or a device.

## 7. Serving API

All new endpoints are public reads (no auth), consistent with vehicle reads
(PLAN.md 6.5). Rate limits are per IP.

### 7.1 `GET /v1/lines/:id/learned-route`

Response:

```json
{ "v": 3, "dir": 0, "polyline": "_p~iF~ps|U...", "points": null, "trips": 47, "computed_at": "2026-10-20T12:00:00Z", "fallback": false }
```

- `v` is `learned_routes.version`; `trips` is `sample_trips`.
- If no active learned route: 200 with `fallback: true` and the static route
  polyline when the line has one, or `polyline: null`.
- `points` is reserved and currently `null`.
- `Cache-Control: public, max-age=300`. Rate limit 60/min/IP.

### 7.2 `GET /v1/lines/:id/stops`

Response:

```json
{ "dir": 0, "stops": [ { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 } ], "fallback": false }
```

- `i` is the ordinal along the published route; `n` is `sample_passes`.
- Without a learned route, the direction is the one with more learned stops.
- If there are no learned stops: 200 with `stops: []` and `fallback: true`.
  There is no static stop fallback in the server response.
- `Cache-Control: public, max-age=300`.

### 7.3 `GET /v1/lines/:id/eta`

Query: `stop` (uuid, required), optional `vehicle` (vehicle id from the
snapshot). Without `vehicle`, returns ETAs for all live vehicles on the line.

Response:

```json
{ "stop": "uuid", "now": 1730000000, "items": [ { "vehicle": 12, "eta_s": 240, "conf": "high", "n": 38 } ], "next_scheduled_s": null }
```

- `next_scheduled_s` is reserved and currently `null`; the client uses the
  timetable directly.
- Computed on demand with a 10 s cache header.
- Rate limit 120/min/IP.

### 7.4 `GET /v1/learned-routes?bbox=latMin,lngMin,latMax,lngMax`

Bulk index for place search. Returns active learned routes with their stops for
lines whose polyline or stops intersect the optional bounding box.
`Cache-Control: public, max-age=300`.

### 7.5 Client data flow

- `LearningRepository` in `app/lib/data/learning/` fetches the learned route,
  stops, ETA and bulk index over HTTP with an 8 s timeout.
- The map draws the learned polyline when present, else the static route, else
  nothing.
- Place search uses the bulk index and degrades to no results on 404 or
  failure.
- The personal-arrival card requests an ETA for the snapped stop. Only line and
  stop ids are sent; the viewer position stays on the device.

## 8. Client changes summary

- Repository: `app/lib/data/learning/learning_repository.dart`.
- Domain models: `LearnedRoute`, `LearnedStop`, `LearnedRoutesIndex`,
  `EtaEstimate` in `app/lib/domain/learning/`.
- Map, place search and personal arrival consume those models.
- The privacy center calls `DELETE /v1/me/learning` from a confirmed
  "stop contributing" action. It is one-way and reports offline honestly.
- No change to trip sharing, battery, or foreground service logic.
  `TripController` remains the only place that starts or stops the service.

## 9. Configuration and tunables

Runtime values live in `app_config`; defaults are compiled in. The keys read by
`server/src/learning/config.ts` are:

| Key | Default | Meaning |
| --- | --- | --- |
| `learning_enabled` | `true` | master switch for the subsystem |
| `learning_min_consent_version` | `2` | minimum consent version for contribution |
| `learning_trim_ends_s` | `120` | seconds trimmed from each trip end |
| `learning_flush_interval_s` | `300` | safety-net flush period |
| `learning_corridor_cell_m` | `50` | absolute corridor grid cell size (m) |
| `learning_stop_cluster_radius_m` | `30` | stop matching radius (m) |
| `learning_stop_speed_mps` | `1.0` | dwell speed threshold |
| `learning_min_dwell_s` | `5` | minimum dwell duration |
| `learning_default_speed_mps` | `6` | fallback speed |
| `learning_default_dwell_s` | `20` | fallback dwell |

`learning_corridor_cell_m` is a geometry invariant for existing accumulators.
Changing it in place would reinterpret stored cell keys at the new size. Before
changing it, truncate `learning_route_cells`, `learning_route_edges` and
`learning_route_state` for the affected lines and let them re-learn. The same
applies to the compiled grid origin.

Removed in v2: `learning_min_route_trips`, `learning_min_trip_route_m`,
`learning_min_stop_passes`, `learning_k_min`, `learning_cache_ttl_s`,
`learning_headway_horizon_s`, `learning_recompute_every_n_trips`,
`stopMinDistinctDays`, `corridorMinCells`, `minRouteLengthM`, and the
`LEARNING_PRIVACY_MODE` env var with its `route_stops` mode. The code ignores
these keys if they remain in an old `app_config` row.

Client-side fallback constants mirror these where needed, but the server value
always wins (PLAN.md 7).

## 10. Privacy controls

- There is no k-anonymity gate. Routes, stops, dwell stats and segment stats are
  published and served from the first sample. Every served row carries its
  sample count, and the client can present low-confidence estimates honestly.
- The accepted tradeoff: one consenting rider's trip can shape a route, a stop
  centroid, or a histogram bucket. Controls that remain are consent, opt-out,
  end trimming, aggregate-only storage, no device or trip ids, and no raw
  tracks. Lawyer and DPO sign-off is required before public release.
- The previous 5-trip device gate, `kMin`, distinct-days suppression,
  `minStopPasses`, and terminus dwell suppression are removed. They were
  eligibility and serving gates, not ingestion filtering.
- Distinct-trip counting no longer uses a salted per-flush hash because no
  distinct-trip gate remains.
- Stop centroids are weighted means across passes. Route cell centroids are
  weighted means across contributing trips. Neither stores an individual fix.
- Logs use the existing `Log` wrapper, which has no API accepting coordinates.
  Learning metrics are counters only: trips contributed, flushes, flush
  failures, direction assignments, trips with a long gap, no-cell transitions, route
  publications, retirements, oversized routes, chain-too-small, and no-flap
  suppressions. No coordinates, ids, or per-line counts.
- The `no_location_at_rest` test scans every migration and rejects location-like
  columns outside `learned_stops` and `learning_route_cells`.
- Synthetic/test traffic is excluded with the optional `synthetic` flag. The
  flag is not persisted and has no security effect; a real rider could use it to
  skip one trip's contribution, which is equivalent to a per-trip opt-out.

## 11. Retention and deletion

- Aggregates are cumulative. A stop with no pass for 90 days is marked
  inactive; an inactive stop is deleted when its last pass is older than 180
  days. `learning_dwell_bins`, `learning_travel_bins`, `stop_dwell_stats` and
  `segment_stats` cascade with the stop.
- `learned_routes`: retired rows are deleted after 30 days. Active rows stay
  until replaced.
- `learning_route_cells` and `learning_route_edges`: kept while the line and
  direction exist because the published route is rebuilt from them. Their size
  is bounded by the fixed grid and the line count.
- `learning_route_state`: kept with the route.
- `DELETE /v1/me` cascades the device row, including `learning_opt_out`. No
  aggregate row references a device.
- `DELETE /v1/me/learning` sets the opt-out flag; future trips do not
  contribute. The privacy center exposes this as a confirmed, one-way action.
  A trip already in progress can finish contributing. Past aggregates are not
  recomputed because they cannot be attributed.
- The earlier rolling 90-day stat deletion is replaced by the stop lifecycle.
  Cumulative histograms have no per-trip timestamps, so deleting only the
  derived stat row while its bins remained would not delete the underlying
  data. This deviation is recorded in D109 and needs legal review.

## 12. Performance and resource budgets

- No per-fix database writes. A trip end triggers one transaction for stops,
  bins and stats, plus the cell/edge/state statements and one route publish.
- Working state is bounded by `maxSamplesPerTrip` (200) per active trip and is
  dropped at trip end. A global memory cap is not enforced in this version.
- Contribution and publication run in a serialized async queue, not on the
  request path. A slow database delays learning, not live sharing.
- Reads are indexed queries on aggregate keys. HTTP cache headers absorb repeat
  reads.
- Histogram size is bounded by the number of stops times 96 hour buckets times
  7 days times the distinct 5-second duration bins actually observed. Monitor
  `learning_dwell_bins` and `learning_travel_bins` growth in production.
- Deno permissions are unchanged: no new write, run, or ffi permission.

## 13. Testing strategy

Unit (Deno, pure functions, no database):
- `learning_corridor_test.ts`: partial trips form one chain, opposite
  directions stay separate, gap handling, simplification and size budget.
- `learning_test.ts`: fake SQL exercising first-trip publication, cumulative
  bins, a single dwell and segment, two samples in one bucket, per-event
  midnight bucketing, short trips surviving the trim, stop ordinals, and the
  synthetic-trip exclusion.
- `trip_schema_test.ts`: the optional `synthetic` field is accepted as a boolean
  and rejected otherwise.
- `learning_eligibility_test.ts`: every consenting, non-opted-out trip is
  accepted; old consent and opt-out contribute nothing.
- `learning_retention_test.ts`: the purge deactivates and deletes dormant
  stops and never deletes stats while their bins remain.
- `no_location_at_rest_test.ts`: the migration column allow-list.
- `config_test.ts` and `metrics_test.ts`: removed env/config and counter
  behavior.

Integration (against PostgreSQL 18.6, existing security suite):
- Migrations 0001 to 0006 apply cleanly, and the 0006 down migration rolls back
  and reapplies cleanly.
- The full server suite passes with `TEST_DATABASE_URL`: 136 passed, 0 failed.
- Flush writes only aggregate rows; no raw fix columns exist.
- Consent, opt-out and synthetic paths do not write aggregates.
- A row with one sample is served; there is no withholding gate.

Privacy audit:
- Grep learning files for coordinate logging; CI check.
- Migration column allow-list per table.

## 14. Status

Implemented in 0.3.x: event plumbing, corridor learning, stop detection,
cumulative dwell and segment histograms, ETA prediction, learned-route
persistence, client seams and the server opt-out endpoint. `learning_enabled`
defaults to true.

D109 (2026-11-12) replaced the 5-trip eligibility gate, `devices.learning_trips`,
`learning_min_route_trips`, `corridorMinCells`, `minRouteLengthM`,
`minStopPasses`, `kMin`, distinct-days suppression and `LEARNING_PRIVACY_MODE`
with DB-backed accumulators and single-sample serving. See the ADR for the
accepted risk and the evidence.

Remaining before release: lawyer/DPO sign-off and RIPD finalisation. The
privacy center now exposes the one-way stop-contributing action; a re-enable
path is not offered.

## 15. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| One trip shapes a route, stop or histogram | Re-identification of a rider's trip | Consent, opt-out, trimming, no ids, legal review; label sample counts in the UI |
| Simulator traffic reaches production | Fake aggregates | The simulator sends `synthetic: true`; the server ignores those trips for learning without changing live sharing |
| Long-lived cumulative bins | Growing storage and retained history | Stop lifecycle retention (90 days inactive, 180 days total); monitor table growth |
| Route changes (construction, detours) | Stale polyline | A changed route is replaced once median deviation exceeds 15 m; keep the static route as fallback |
| Direction misclassification on circular lines | Mixed samples corrupt the chain | Two directions per line, coverage then bearing; single direction for circulars is not automatic |
| Database unavailable | Learning stops | Live sharing continues; failures are counted and retried by later trips |
| Process dies before a queued contribution | One trip is lost | The DB keeps prior accumulators; no raw trip is stored for replay |
| Oversized polyline | No new version | 8192-character cap; keep the active geometry and update confidence |
| Migration risk on production | Downtime | Forward-only; test on staging; owner runs the migration per runbook |

## 16. Decisions

Decided: opt-out default on (ADR 2026-10-26); learned route auto-replaces
static geometry when published; every organic trip contributes; DB-backed
accumulators; single-sample serving; 15 m median-deviation version churn
control; stop-lifecycle retention (D109).

Still open: public ETA exposure, max directions per line (2 recommended), a
re-enable path if the owner decides opt-out must be reversible, a separate
model-serving process (defer until the CPU budget requires it), and a true
rolling window if legal review requires one.

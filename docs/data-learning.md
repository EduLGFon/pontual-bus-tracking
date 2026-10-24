# Data Learning Plan: Route, Stops, Dwell, and ETA

Status: draft design document. Scope: **[L]** (later), gated by D20. This
document proposes a light, in-process learning subsystem that consumes the
existing trip-sharing event stream and produces de-identified aggregates
for route geometry, stops, dwell times, segment travel times, and ETA
prediction. It does not change alpha behavior. Nothing here may be built
without the legal gate in section 2 passing first.

Companion documents: `PLAN.md` (build contract, sections 5.5, 6, 7, 12, 13),
`DECISIONS.md` (D02, D20, D30, D46), `docs/privacy/inventory.md`,
`docs/privacy/ripd.md`.

---

## 0. Purpose and status

Pontual today serves live vehicle positions built from rider pings, plus
static timetables and (for pilot lines) hand-recorded route polylines. The
goal of this subsystem is to let the crowd-sourced trips themselves teach
the system:

1. The driven way-path of each line, as a polyline usable for map drawing
   and for distance/progress calculations.
2. The stops a bus actually serves on each street, with dwell time
   distributions by time of day, day of week, and date.
3. Real ETA and arrival prediction from current pace plus historic
   segment and stop data.

The subsystem is deliberately **light**: no heavy ML framework, no per-fix
database writes, no raw track storage, and no new runtime beyond the
existing Deno API process. It reuses the in-process event bus, the
existing pure domain layer, and the aggregate-only storage rule from D20.

Scope tags follow `PLAN.md` 0.2: **[A]** alpha, **[A\*]** alpha should,
**[L]** later. Everything in this document is **[L]** unless marked
otherwise.

---

## 1. Goals and non-goals

### 1.1 Goals

- Learn a centerline polyline per line and direction from accepted trip
  fixes, with a confidence/sample count, and serve it as a versioned
  replacement for (or fallback to) the static route file.
- Detect stops from repeated low-speed dwells, cluster them into stable
  stop points, and assign each a stable id and ordinal along the route.
- Store dwell time statistics per stop by time bucket (15 minute and
  hourly), day of week, and rolling date window, with min/max/median and
  sample counts.
- Store segment travel time statistics between consecutive stops by the
  same time buckets.
- Produce ETA predictions for a vehicle to downstream stops using
  current position, current pace, and the historic segment/dwell stats.
- Produce next-bus arrival estimates at a stop from live vehicles plus
  historic headway.
- Keep the privacy contract: no raw fixes, no device or trip ids, no
  client timestamps, trim trip ends, min group sizes, consent bump, RIPD
  update, lawyer review.

### 1.2 Non-goals

- Turn-by-turn navigation or point-to-point routing (explicitly out of
  scope in `PLAN.md` 1.2).
- Exact per-vehicle or per-driver profiling.
- Real-time traffic ingestion from third parties.
- A separate ML serving cluster in alpha of this subsystem. Model serving
  stays in-process; a separate process is a later option (`PLAN.md` 5.5).
- Replacing the static timetable. Timetables remain static JSON
  (`PLAN.md` D07). Learned dwell/travel times complement them.
- Learning from any data source other than accepted fixes from consenting
  riders. No scraping, no operator feeds (care rules in `PLAN.md` 7.5).

### 1.3 Success criteria

- A line with at least `minRouteTrips` (default 20) completed trips in a
  direction produces a learned polyline whose median distance to the
  hand-recorded route (where one exists) is under 40 m.
- Stop detection precision/recall against a manually labelled set of
  stops on two pilot lines is at least 0.8 each.
- ETA median absolute error at 5 minutes horizon is under 90 s on a
  held-out week of simulator trips.
- Prediction endpoints add less than 5 ms p99 to snapshot build time and
  no new per-fix database write.
- Privacy audit: no raw coordinate, device id, or trip id in any new
  table, log line, or metric. Extends the existing `no_location_at_rest`
  check.

---

## 2. Privacy and legal gate (D20)

This subsystem is the concrete instance of the future path allowed by D20.
It is blocked until all of the following are done and recorded in
`DECISIONS.md`:

1. Consent text version bump (new `consent_version` value, e.g. 2) with
   explicit wording that de-identified, aggregated travel and dwell
   statistics may be derived from shared trips. Old consent version stays
   valid for live sharing only; aggregates are only updated from trips
   whose rider consented to the new version.
2. RIPD update in `docs/privacy/ripd.md` covering the new processing
   purpose, the aggregate data inventory, retention, and re-identification
   risk assessment.
3. Data inventory update in `docs/privacy/inventory.md` listing every new
   table and field.
4. Lawyer review of the consent wording and the aggregate schema before
   the first byte is stored.
5. Owner decision on whether aggregate publication is opt-in or part of
   the base consent (recommendation: part of base consent v2, with a
   separate opt-out toggle in settings that stops the device from
   contributing, without affecting live sharing).

Additional hard rules inherited from `PLAN.md` 8 and 15:

- No raw per-trip tracks, ever. Only accumulators and cluster centroids.
- Trim the first and last `trimEndsS` (default 120) seconds of every
  trip before aggregation, to remove boarding/alighting and home
  endpoints.
- No device id, trip id, session id, or client timestamp in any
  aggregate row or event payload consumed by this subsystem.
- Minimum group size `kMin` (default 5 distinct trips) before an
  aggregate is published or served. Below `kMin`, the aggregate is
  withheld and the client falls back to the next coarser bucket or to
  static data.
- Distinct-trip counting uses an in-memory, per-flush salted hash of a
  trip nonce that is discarded after the flush. The nonce is not
  persisted and cannot be joined back to a device.
- Aggregates are keyed by line, direction, segment/stop, and time bucket
  only. Never by rider.
- Retention: rolling 90 days for segment/dwell stats; learned routes and
  stops persist until superseded by a newer version, with old versions
  kept for 30 days for rollback.

---

## 3. High-level architecture

```
Trip sharing (existing)
  ping.ts / tick.ts
        |
        v
EngineEvent bus (expanded)
        |
        v
LearningConsumer (new, in-process)
  - per-trip working state (memory only, discarded on TripEnded)
  - accumulator store (memory)
        |
        | periodic flush (every flushIntervalS, default 300)
        v
PostgreSQL aggregate tables (new migration)
        |
        v
LearningReadModel (in-process cache, refreshed every cacheTtlS)
        |
        v
HTTP/WS (new endpoints + optional snapshot fields)
        |
        v
Flutter client (route/stops/ETA layers)
```

Key properties:

- The engine (`domain/`) stays pure and synchronous. It emits events only.
  It never imports the learning module.
- The learning consumer is a stateful subscriber in the server layer
  (`state/` or a new `learning/` package), not in `domain/`.
- Working state for an in-flight trip lives only in memory and is dropped
  on `TripEnded`, including on crash. No recovery of in-flight learning
  state is attempted.
- Database writes happen only in the flush step, are batched, and use
  upserts on aggregate keys.
- Serving reads from an in-process cache refreshed from the database on a
  TTL, so request paths never hit PostgreSQL for learning data.

Directory placement (new):

```
server/src/learning/
  consumer.ts        # subscribes to events, owns working state
  aggregator.ts      # pure-ish accumulators and flush logic
  routeLearner.ts    # centerline algorithm
  stopDetector.ts    # dwell clustering
  stats.ts           # segment/dwell accumulators
  predictor.ts       # ETA computation
  cache.ts           # read model + TTL refresh
  types.ts           # aggregate types
```

`domain/` gains only new event variants (section 4). No other change to
the pure layer.

---

## 4. Event contract expansion

Today `EngineEvent` has two variants:

- `vehicleUpdated: { lineId }`
- `tripEnded: { lineId, reason }`

The learning consumer needs fix-level progress without storing raw fixes.
Add three variants. Each carries only what an aggregate needs; no device
id, no trip id beyond an opaque in-memory token.

```ts
type EngineEvent =
  | { kind: "vehicleUpdated"; lineId: number }
  | { kind: "tripEnded"; lineId: number; reason: EndReason }
  | {
      kind: "tripStarted";
      lineId: number;
      tripKey: string;      // opaque, in-memory only, never persisted
      startedAtMs: number;
      lat: number;
      lng: number;
    }
  | {
      kind: "fixAccepted";
      lineId: number;
      tripKey: string;
      atMs: number;
      lat: number;
      lng: number;
      speedMps: number;
      heading: number | null;
      accuracyM: number;
    }
  | {
      kind: "vehicleRemoved";
      lineId: number;
      vehicleId: number;
    };
```

Emission points (in `ping.ts`/`tick.ts`):

- `startTrip`: emit `tripStarted` with the first fix. `tripKey` is a fresh
  random UUID generated in the server layer and held only in the
  consumer's working map; the engine never stores it.
- `applyPing` accepted fix: emit `fixAccepted`.
- `endTrip`: the consumer finalises the trip's working state on
  `tripEnded` (already emitted). No new event needed; the consumer
  watches `tripEnded` and keys working state by `tripKey`... but
  `tripEnded` does not carry `tripKey` today.

Resolution: `tripEnded` must carry `tripKey`. Change its shape to
`{ kind: "tripEnded"; lineId: number; tripKey: string; reason: EndReason }`.
This is an internal event, not a wire contract, so the change is safe.
The consumer removes working state on receipt.

Privacy note: `tripKey` never leaves the process and is never logged. It
exists only to correlate fixes within one trip in memory.

Throttling: `fixAccepted` is emitted for every accepted fix. The consumer
downsamples to at most one sample per `minSampleSpacingM` (default 20 m)
of travel or `minSampleSpacingS` (default 10 s), whichever comes first,
before updating working state. This bounds memory and CPU.

---

## 5. Aggregation model and data structures

### 5.1 In-memory working state (per trip, discarded on end)

```ts
interface TripWork {
  tripKey: string;
  lineId: number;
  direction: number;          // 0 or 1, assigned at end
  consentVersion: number;     // only >= minConsentVersion contributes
  startedAtMs: number;
  samples: Array<{ t: number; lat: number; lng: number; speed: number }>;
  dwell: Array<{ lat: number; lng: number; startMs: number; endMs: number }>;
  totalDistanceM: number;
}
```

Rules:

- If `consentVersion < minConsentVersion` (default 2), the consumer
  ignores the trip entirely. No working state is created.
- Samples are trimmed: drop samples with `t < startedAtMs + trimEndsS*1000`
  and samples after `endedAtMs - trimEndsS*1000`.
- `samples` is capped at `maxSamplesPerTrip` (default 200); excess is
  uniformly downsampled.
- Memory budget: 200 trips * 200 samples * ~40 bytes ~ 1.6 MB plus
  overhead. Acceptable.

### 5.2 Accumulator store (in-memory, flushed periodically)

```ts
interface RouteAccumulator {
  lineId: number;
  direction: number;
  // bins along normalised progress 0..1
  bins: Map<number, { latSum: number; lngSum: number; n: number }>;
  tripCount: number;
  lastFlushMs: number;
}

interface StopCluster {
  lineId: number;
  direction: number;
  centroidLat: number;
  centroidLng: number;
  radiusM: number;
  passCount: number;
  samples: number;            // capped reservoir for re-clustering
}

interface DwellAccumulator {
  stopId: string;             // internal cluster id, not a wire id
  hourBucket: number;         // 0..23 or 0..95 for 15-min
  dayOfWeek: number;          // 0..6
  count: number;
  sumS: number;
  minS: number;
  maxS: number;
  // for median: reservoir sample capped at 64
  reservoir: number[];
}

interface SegmentAccumulator {
  lineId: number;
  direction: number;
  fromStop: string;
  toStop: string;
  hourBucket: number;
  dayOfWeek: number;
  count: number;
  sumS: number;
  minS: number;
  maxS: number;
  distanceM: number;
  reservoir: number[];
}
```

Accumulators are flushed to PostgreSQL via upserts, then cleared from
memory for the flushed keys to bound memory. Counters that represent
lifetime sample counts are persisted and reloaded on startup, so
flushing does not lose history.

### 5.3 Direction assignment

Each completed trip gets a direction 0 or 1:

- Compute the vector from the first kept sample to the last kept sample.
- Compare against the mean direction vector of existing accumulators for
  that line.
- If the line has no accumulator yet, direction 0.
- If the trip's vector is within 60 degrees of an existing direction,
  assign that direction.
- Otherwise, if a second direction slot is free (max 2 directions per
  line), create direction 1.
- If neither fits, discard the trip for route learning (it is likely a
  detour or a different service). It still contributes to dwell/segment
  stats only if it snaps to an existing stop sequence.

Max 2 directions per line is a simplification. Circular lines are handled
as a single direction with progress wrapping at 1.0.

### 5.4 Consent gating

The learning consumer receives `consentVersion` from the trip start
payload. The engine does not know consent versions; the server handler
that calls `startTrip` looks up the device's highest consent version and
passes it into the event. If the device has no consent row with version >=
`minConsentVersion`, the trip contributes nothing to learning. Live
sharing is unaffected.

---

## 6. Algorithms

### 6.1 Route learning (centerline)

Input: a set of completed trips for (line, direction), each with an
ordered list of kept samples.

Step 1, per trip normalisation:

- Compute cumulative distance along the trip's own samples using haversine.
- Let `total = last cumulative`. If `total < minRouteLengthM` (default
  500 m), discard (too short, likely noise).
- For each sample, `progress = cumulative / total` in [0, 1].
- Bin into `routeBins` (default 200) equal-width progress bins. For each
  bin, store the median lat/lng of the samples in that bin (median of
  lats, median of lngs independently). This removes within-trip jitter.

Step 2, cross-trip aggregation:

- For each bin index, collect the per-trip median points.
- Bin centroid = median of those latitudes and longitudes.
- Require at least `minRouteTrips` (default 20) trips contributing to a
  bin before it is trusted. Missing bins are interpolated linearly
  between the nearest trusted bins. If more than 20% of bins are missing,
  the route is not published.

Step 3, smoothing and simplification:

- Apply a 3-point moving average along the sequence of bin centroids to
  reduce zigzag.
- Run Douglas-Peucker at 5 m tolerance (reuse `tools/route` logic,
  ported to TypeScript in `routeLearner.ts`).
- Encode as polyline precision 5.
- Size check: must be <= 8 KB. If larger, increase tolerance to 10 m and
  retry; if still larger, reject publication.

Step 4, gating and versioning:

- Compute `medianDeviationM` between the new polyline and the currently
  published one (if any), sampled at 50 points. If deviation < 15 m,
  keep the old version (no flapping).
- Otherwise insert a new `learned_routes` row with status `candidate`.
- Promote to `active` only after `promotionTrips` (default 10)
  additional trips agree within 20 m median. This avoids a single bad
  week flipping the route.
- Keep the previous active version for 30 days.

Cold start: if no static route exists and no learned route is active,
the line has no polyline. The client draws nothing, as today.

### 6.2 Stop detection and clustering

Per trip:

- Walk the kept samples. A dwell is a maximal run where instantaneous
  speed (or smoothed speed over 3 samples) is below `stopSpeedMps`
  (default 1.0 m/s) for at least `minDwellS` (default 10 s).
- For each dwell, record its centroid (median lat/lng of the run) and
  duration.
- Drop dwells whose centroid is within `trimEndsS` of trip start/end
  (already handled by sample trimming, but check again).

Cross-trip clustering (DBSCAN-like, run at flush time):

- For each (line, direction), collect all dwell centroids from the flush
  batch plus the existing stop clusters.
- Cluster with radius `stopClusterRadiusM` (default 30 m) and min points
  `stopMinPasses` (default 4).
- A cluster that reaches `stopMinPasses` becomes (or updates) a
  `learned_stops` row. Its centroid is the median of member centroids.
- Stop ordinal along the route is assigned by projecting each stop
  centroid onto the active learned polyline (or static route if no
  learned one) and sorting by cumulative distance.
- A stop cluster with no new pass for `stopDecayDays` (default 30) days
  is marked `active = false` but retained for 90 days.

Stop identity stability: cluster ids are matched across flushes by
nearest centroid within 40 m. If no match, a new id is minted. Ids are
UUIDs generated server-side and are not derived from location.

### 6.3 Dwell time statistics

For each detected dwell at a stop:

- `hourBucket` = floor(minute-of-day / 15) (0..95) for 15-minute
  resolution, and a parallel hourly rollup.
- `dayOfWeek` = ISO day of week of the dwell's start, in America/Sao_Paulo.
- `dateBucket` = ISO date of the dwell's start. Stored only in the
  daily rollup table and only when the (stop, date) group reaches
  `kMin`. In practice this will be sparse; the hourly/dow rollup is the
  primary serving granularity.

Accumulator update (online, in memory):

- Find or create the (stop, hourBucket, dayOfWeek) accumulator.
- Update count, sum, min, max, and reservoir (capped 64, reservoir
  sampling) for median.
- Median is computed at flush time from the reservoir plus the persisted
  reservoir, using a merge step, then the reservoir is reset.

Serving returns p50 and p90 (nearest-rank) plus count. If count < kMin,
the bucket is withheld and the client uses the next coarser bucket
(hour-of-day ignoring dow, then global stop median).

### 6.4 Segment travel time statistics

Between consecutive stops along a trip's snapped stop sequence:

- For each pair of consecutive stops (A, B) that the trip actually
  served (both detected as dwells), compute travel time = B.startMs -
  A.endMs (i.e., excluding dwell at A, including running time).
- Distance = polyline distance between A and B centroids.
- Accumulate per (line, direction, fromStop, toStop, hourBucket,
  dayOfWeek) as in 6.3.
- Also maintain a global (line, direction, fromStop, toStop) accumulator
  ignoring time, as the fallback.

These stats feed ETA. They are also the basis for the future "per-route-
segment travel time by hour of week" aggregate mentioned in D20.

### 6.5 ETA prediction

For a given vehicle and a target downstream stop S:

1. Snap the vehicle to the active polyline (or static route). Compute
   progress `p` (0..1) along it. If no route, fall back to straight-line
   distance / assumed speed.
2. Find the next stop at progress > p (call it `nextStop`). If the
   vehicle is between `nextStop` and the one after, handle normally.
3. Remaining stops = stops from `nextStop` to S inclusive.
4. For each remaining segment between consecutive stops (Ai, Ai+1):
   - Look up segment stats for (line, direction, Ai, Ai+1, hourBucket,
     dayOfWeek). If count < kMin, try (hourBucket only, any dow), then
     global.
   - Base time = p50 of the chosen bucket, or distance / defaultSpeedMps
     if none.
   - Adjust by current pace: `factor = clamp(histSpeed / currentSpeed, 0.5, 2.0)`
     where histSpeed = distance / baseTime, currentSpeed = max(vehicle.paceMps,
     1 m/s). Adjusted = baseTime * factor.
   - Add dwell at Ai+1 (p50 for that stop/bucket, or global stop median,
     or defaultDwellS).
5. Sum adjusted times. Add a "current segment" partial: from vehicle
   position to nextStop using distance / currentSpeed (capped at 2x the
   historic segment rate).
6. Return `{ etaS, confidence, sampleCount, method }`. Confidence is
   "high" if all buckets used had count >= 2*kMin, "medium" if some
   fallback, "low" if mostly defaults.

Output is computed on demand in `predictor.ts` and cached for 10 s per
(vehicle, stop) to avoid recomputation. It is never stored.

Headway prediction (next bus at a stop):

- For the target stop, find live vehicles downstream/upstream within a
  window. For each, compute ETA to the stop as above.
- If no live vehicle is predicted within `headwayHorizonS` (default 1800
  s), fall back to the timetable: next scheduled departure + historic
  median travel time from terminus to the stop.
- Return the minimum ETA among candidates plus the second-best for
  "following bus".

### 6.6 Model serving and update cadence

- Route recompute: triggered when a (line, direction) accumulator reaches
  `recomputeRouteEveryN` (default 5) new trips since last recompute, or
  weekly by a job in `jobs/`. Recompute runs in a background task
  (Deno `setTimeout`/queue), never in a request path.
- Stop recompute: same trigger.
- Stats flush: every `flushIntervalS` (default 300 s) or when an
  accumulator exceeds `flushThresholdRows` (default 1000).
- Read model cache: refreshed every `cacheTtlS` (default 60 s) from the
  database, or immediately after a flush completes.
- All recompute is best-effort; failures are logged (without coordinates)
  and retried next cycle.

---

## 7. Persistence schema (new migration)

Migration file: `server/db/migrations/0003_learning.sql` (number after the
last existing). Forward-only. Grants to `pontual_app` limited to the new
tables.

```sql
-- migrate:up

create table if not exists learned_routes (
  id uuid primary key default gen_random_uuid(),
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  version integer not null,
  status text not null check (status in ('candidate','active','retired')),
  polyline text not null,
  point_count integer not null,
  sample_trips integer not null,
  median_deviation_m real,
  computed_at timestamptz not null default now(),
  promoted_at timestamptz,
  retired_at timestamptz,
  unique (line_id, direction, version)
);
create index if not exists learned_routes_active_idx
  on learned_routes (line_id, direction, status) where status = 'active';

create table if not exists learned_stops (
  id uuid primary key default gen_random_uuid(),
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  ordinal integer not null,
  lat double precision not null,
  lng double precision not null,
  radius_m real not null default 30,
  sample_passes integer not null default 0,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  active boolean not null default true
);
create index if not exists learned_stops_line_dir_idx
  on learned_stops (line_id, direction, active);

create table if not exists segment_stats (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  from_stop uuid not null references learned_stops(id) on delete cascade,
  to_stop uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  sample_count integer not null,
  travel_p50_s real not null,
  travel_p90_s real not null,
  distance_m real not null,
  updated_at timestamptz not null default now(),
  primary key (line_id, direction, from_stop, to_stop, hour_bucket, day_of_week)
);

create table if not exists stop_dwell_stats (
  stop_id uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  sample_count integer not null,
  dwell_p50_s real not null,
  dwell_p90_s real not null,
  updated_at timestamptz not null default now(),
  primary key (stop_id, hour_bucket, day_of_week)
);

create table if not exists learning_watermarks (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  trips_since_route_recompute integer not null default 0,
  trips_since_stop_recompute integer not null default 0,
  last_flush_at timestamptz,
  primary key (line_id, direction)
);

grant select, insert, update, delete on learned_routes to pontual_app;
grant select, insert, update, delete on learned_stops to pontual_app;
grant select, insert, update, delete on segment_stats to pontual_app;
grant select, insert, update, delete on stop_dwell_stats to pontual_app;
grant select, insert, update, delete on learning_watermarks to pontual_app;

-- migrate:down
drop table if exists learning_watermarks;
drop table if exists stop_dwell_stats;
drop table if exists segment_stats;
drop table if exists learned_stops;
drop table if exists learned_routes;
```

Notes:

- `learned_stops.lat/lng` are aggregate centroids. They are the only
  location at rest introduced by this subsystem and are permitted because
  they are not individual locations. The `no_location_at_rest` check must
  be updated to allow these specific columns and to keep rejecting
  everything else.
- No device id, trip id, or client timestamp column exists in any table.
- Daily rollup table is omitted from v1 to keep group sizes meaningful;
  add `stop_dwell_daily` only if a later review shows sufficient volume.

---

## 8. Serving API

All new endpoints are public reads (no auth), consistent with vehicle
reads (`PLAN.md` 6.5). Rate limits per IP.

### 8.1 `GET /v1/lines/:id/learned-route`

Response:

```json
{
  "v": 3,
  "dir": 0,
  "polyline": "_p~iF~ps|U...",
  "points": 142,
  "trips": 47,
  "computed_at": "2026-10-20T12:00:00Z",
  "fallback": false
}
```

- `v` is the `learned_routes.version`.
- If no active learned route, returns `204 No Content` (or `200` with
  `fallback: true` and the static route polyline from the server's data
  bundle). Recommendation: `200` with `fallback: true` and `polyline`
  from the static bundle, so the client always gets something. If no
  static route either, `polyline` is null.
- `ETag` based on version; `Cache-Control: public, max-age=300`.
- Rate limit: 60/min/IP.

### 8.2 `GET /v1/lines/:id/stops`

Response:

```json
{
  "dir": 0,
  "stops": [
    { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 }
  ],
  "fallback": false
}
```

- `i` is the ordinal along the route.
- `n` is `sample_passes`.
- If no learned stops, returns the static stops for that line from the
  server data bundle with `fallback: true` and no `n`.
- `Cache-Control: public, max-age=300`.

### 8.3 `GET /v1/lines/:id/eta`

Query: `stop` (uuid, required), optional `vehicle` (vehicle id from the
snapshot to scope to one bus). If `vehicle` omitted, returns ETAs for all
live vehicles on the line to that stop.

Response:

```json
{
  "stop": "uuid",
  "now": 1730000000,
  "items": [
    { "vehicle": 12, "eta_s": 240, "conf": "high", "n": 38 },
    { "vehicle": 15, "eta_s": 720, "conf": "medium", "n": 12 }
  ],
  "next_scheduled_s": 900
}
```

- `next_scheduled_s` is from the timetable when a live estimate is not
  available or beyond `headwayHorizonS`.
- Rate limit: 120/min/IP (matches vehicle reads).
- Computed on demand with 10 s cache per (line, stop).

### 8.4 Optional snapshot field

The vehicle snapshot `v` array could gain a trailing `eta_next_stop_s`
field for the vehicle's next stop. This is a wire contract change and must
be additive only: old clients ignore trailing fields if they parse by
index carefully. Given the app parses by index today, adding a field
breaks old clients unless they are updated first. Recommendation: do not
add to the snapshot; use the dedicated ETA endpoint and let the client
poll it. Revisit after two releases.

### 8.5 Client data flow

- `LearnedRouteRepository` and `LearnedStopsRepository` in `data/` fetch
  and cache the learned route/stops with ETag revalidation, mirroring
  `VehicleRepository`. Cached on disk with a 1 h TTL and stale-while-
  revalidate.
- `EtaRepository` polls `/v1/lines/:id/eta` for the selected stop every
  30 s when the line detail screen is open.
- Map layer: draw learned polyline if available, else static route, else
  none. Draw learned stops as dots with a tap showing ETA.
- Stop layer is decorative until learned stops exist; no stop picker
  (D83). Selection of "target stop" for ETA uses the nearest learned
  stop to the user's tap, snapped to the route.

---

## 9. Client changes summary

- New repositories in `data/`: `learned_route_repository.dart`,
  `learned_stops_repository.dart`, `eta_repository.dart`.
- New models in `domain/` (pure Dart): `LearnedRoute`, `LearnedStop`,
  `EtaEstimate`. No Flutter imports.
- Map screen: polyline source selection (learned -> static -> none),
  stop dots, ETA bottom sheet.
- Settings: "Contribute anonymous trip statistics" toggle (default on if
  consent v2 accepted). Opt-out calls a new `DELETE /v1/me/learning`
  endpoint that removes the device from future contribution; since no
  device id is stored, this is implemented by recording an opt-out flag
  on the device row and checking it at trip start. The flag is deleted
  with the device.
- Strings: all new UI strings in `ui_strings.dart`, pt-BR.

No change to trip sharing, battery, or foreground service logic.
`TripController` remains the only place that starts/stops the service.

---

## 10. Configuration and tunables

Add to `app_config` (validated, defaults in code):

| Key | Default | Meaning |
|---|---|---|
| `learning_enabled` | `false` | master kill switch for the whole subsystem |
| `learning_min_consent_version` | `2` | min consent version for contribution |
| `learning_min_route_trips` | `20` | trips before a route is published |
| `learning_min_stop_passes` | `4` | passes before a stop is published |
| `learning_k_min` | `5` | min group size for any aggregate |
| `learning_trim_ends_s` | `120` | seconds trimmed from each trip end |
| `learning_flush_interval_s` | `300` | aggregate flush period |
| `learning_cache_ttl_s` | `60` | read model refresh |
| `learning_route_bins` | `200` | progress bins for centerline |
| `learning_stop_cluster_radius_m` | `30` | DBSCAN radius |
| `learning_stop_speed_mps` | `1.0` | dwell speed threshold |
| `learning_min_dwell_s` | `10` | min dwell duration |
| `learning_headway_horizon_s` | `1800` | max horizon for next-bus |
| `learning_default_speed_mps` | `6` | fallback speed |
| `learning_default_dwell_s` | `20` | fallback dwell |

Client-side fallback constants mirror these but the server value always
wins (`PLAN.md` 7, architecture rules).

---

## 11. Privacy controls and k-anonymity

- `kMin` applies to every served aggregate. Below it, withhold and fall
  back.
- Additional suppression: if a (stop, hour, dow) bucket has count >= kMin
  but the stop has fewer than `minDistinctDays` (default 3) distinct
  dates contributing, withhold, to prevent single-day identification.
- Distinct-trip counting uses a per-flush salted hash of a trip nonce
  discarded after flush. No join key persists.
- Aggregates never include origin/destination trimming beyond `trimEndsS`;
  if a line has only one stop cluster (terminus), suppress dwell stats
  there to avoid home inference. Actually suppress the first and last
  stop's dwell stats entirely, since terminus dwell reveals rider
  boarding/alighting patterns. Only intermediate stops get dwell stats.
- Route polyline is an aggregate of many trips; individual trips cannot be
  recovered. Still, apply a minimum of `minRouteTrips` before publishing.
- Logs: the learning module uses the existing `Log` wrapper, which has no
  API accepting coordinates. Add a lint rule / test that greps new files
  for coordinate-like logging.
- Metrics: counters only (trips contributed, flushes, cache hits). No
  coordinates, no ids, no per-line counts below kMin (report "lines with
  data" only as a boolean per line).

---

## 12. Retention and deletion

- `segment_stats` and `stop_dwell_stats`: rolling 90 days. A daily job
  deletes rows whose `updated_at < now() - 90 days`. Counts are
  decremented; if a (key) loses all rows it is removed.
- `learned_routes`: keep active + previous for 30 days; delete retired
  older than 30 days.
- `learned_stops`: keep inactive for 90 days, then delete, cascading to
  stats.
- `learning_watermarks`: no expiry; tiny.
- `DELETE /v1/me` (existing) cascades device rows; since no learning
  row references a device, nothing extra is needed, but the opt-out flag
  goes with the device.
- `DELETE /v1/me/learning` sets the opt-out flag; future trips from that
  device do not contribute. Past aggregates are not recomputed (they
  cannot be attributed).

---

## 13. Performance and resource budgets

- No per-fix database writes. Flush is batched every 5 min.
- Working state memory cap: 50 MB. If exceeded, new trips are not
  tracked for learning (live sharing unaffected) and a counter is
  incremented.
- Recompute runs in a background task with a 30 s time budget; if it
  exceeds, abort and retry next cycle.
- Read model cache refresh is incremental (only changed rows since
  `last_refresh_at`).
- CPU: learning adds at most 5% overhead to the ping path (measured by
  the existing perf harness).
- Deno permissions unchanged: no new `--allow-write`/`run`/`ffi`.

---

## 14. Testing strategy

Unit (Deno, pure functions, no DB):

- `routeLearner`: centerline on synthetic trips recovers a known
  polyline within 5 m; trimming drops endpoints; direction assignment;
  simplification size budget.
- `stopDetector`: synthetic dwell runs produce clusters; noise dwells
  below min duration are dropped; terminus suppression.
- `stats`: accumulator upserts, reservoir median, kMin withholding,
  fallback chain.
- `predictor`: ETA on a known route with known stats returns expected
  value within 1%; fallback to defaults when no stats.

Integration (against test PostgreSQL, as existing security suite):

- Flush writes only aggregate rows; `no_location_at_rest` extended
  asserts no raw fix columns exist and no row contains a coordinate
  outside the set of known stop/route centroids.
- Consent gating: trips with consent v1 do not increment any counter.
- Opt-out: flagged device's trips do not contribute.
- kMin: buckets below threshold are not served (404/empty + fallback).
- Migration applies cleanly and rolls back.

Property/fuzz:

- Aggregator never throws on empty trips, single-sample trips, or
  zero-distance trips.
- Predictor never returns negative ETA.

Privacy audit:

- Grep learning files for coordinate logging; CI check.
- DB dump inspection in tests: column allow-list per table.

---

## 15. Milestones and tasks

Phase 0, spikes (before any code):

- S-L1: map-match-free centerline quality on simulator trips. Build a
  small offline script in `tools/` that runs the route algorithm on
  simulator output and reports deviation vs. the input route. Gate:
  median < 40 m on two lines.
- S-L2: consent wording and RIPD review with the owner's lawyer. Gate:
  written approval.
- S-L3: group-size feasibility: run the simulator for a week-equivalent
  and check that intermediate-stop buckets reach kMin. If not, raise kMin
  lowering or accept sparser data.
- S-L4: performance: recompute on 10k trips in < 30 s.

Phase 1, event plumbing and in-memory aggregator (no DB, no serving):

- T-L1: expand `EngineEvent` variants and emission points.
- T-L2: implement `learning/consumer.ts` with working state and
  downsampling.
- T-L3: implement accumulators and flush to a no-op sink; add tests.
- T-L4: consent gating and opt-out flag on devices (migration 0003
  partial: add `learning_opt_out boolean` to devices? Actually keep a
  separate `device_learning_opt_outs` table or a column. Recommendation:
  add column `learning_opt_out boolean not null default false` to
  `devices` via migration 0003. Simpler and cascades on delete.)

Phase 2, persistence and route learning:

- T-L5: migration 0003 (full schema).
- T-L6: implement flush upserts and read model cache.
- T-L7: implement route learner and recompute job.
- T-L8: `GET /v1/lines/:id/learned-route`.
- T-L9: client `LearnedRouteRepository` and map polyline selection.

Phase 3, stops and dwell stats:

- T-L10: stop detector and clustering.
- T-L11: dwell and segment accumulators + flush.
- T-L12: `GET /v1/lines/:id/stops`.
- T-L13: client stop dots.

Phase 4, ETA:

- T-L14: predictor implementation.
- T-L15: `GET /v1/lines/:id/eta`.
- T-L16: client ETA bottom sheet and polling.
- T-L17: headway fallback to timetable.

Phase 5, hardening:

- T-L18: privacy audit and `no_location_at_rest` extension.
- T-L19: performance and memory budget tests.
- T-L20: docs (inventory, RIPD, policy) and consent v2 text.
- T-L21: owner sign-off and flip `learning_enabled` default to true.

Each task is one logical change set, with acceptance criteria and tests,
per `PLAN.md` 0.3 and 16.

---

## 16. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Low rider volume -> buckets never reach kMin | No learned data served | Fall back to static route/stops/timetable; keep collecting; lower kMin only after S-L3 |
| Route changes (construction, detours) | Stale polyline | Decay and recompute weekly; candidate/promotion gate prevents flapping; manual invalidation via app_config |
| Direction misclassification on circular lines | Mixed samples corrupt centerline | Single direction for circulars; detect by start/end proximity |
| Re-identification via rare (stop, hour, dow) buckets | Privacy breach | kMin + distinct-days suppression + terminus suppression; lawyer review |
| Memory blowup on busy days | Process OOM | 50 MB cap; drop learning tracking, keep live sharing |
| Recompute CPU spikes | Latency | Background task with 30 s budget; abort and retry |
| Learned route worse than static | Bad UX | Median-deviation gate; keep static as fallback; manual rollback via version |
| Consent confusion | Legal | Separate opt-out toggle; clear wording; version bump |
| Migration risk on production | Downtime | Forward-only; test on staging; owner runs migration per runbook |

---

## 17. Open decisions for the owner

1. Opt-in vs. opt-out for contributing aggregates (recommendation:
   opt-out toggle, default on, only after consent v2).
2. Whether learned routes should auto-replace static routes in the client
   or require a manual "use community route" toggle (recommendation:
   auto-replace when confidence high, with a "report wrong route" link).
3. Whether to expose ETA publicly or only to consenting riders
   (recommendation: public, since it is aggregate and contains no rider
   data).
4. Max directions per line: 2 (recommendation) vs. N.
5. Whether to store a daily rollup table (recommendation: defer until
   volume justifies).
6. Whether model serving should move to a separate process (recommendation:
   defer; in-process is fine until CPU budget is hit).

---

## Appendix A: centerline pseudocode

```
function learnRoute(trips, routeBins=200):
  perTripBins = []
  for trip in trips:
    samples = trim(trip.samples, trimEndsS)
    if totalDistance(samples) < minRouteLengthM: continue
    cum = 0
    bins = map of binIndex -> {lats:[], lngs:[]}
    prev = samples[0]
    for s in samples[1:]:
      cum += haversine(prev, s)
      progress = cum / totalDistance(samples)
      bi = floor(progress * routeBins) clamped to [0, routeBins-1]
      bins[bi].lats.push(s.lat)
      bins[bi].lngs.push(s.lng)
      prev = s
    perTripBins.push(bins)

  if len(perTripBins) < minRouteTrips: return None

  centroids = []
  for bi in 0..routeBins-1:
    pts = [median(b.lats), median(b.lngs) for b in perTripBins if bi in b]
    if len(pts) < minRouteTrips * 0.8:
      centroids.push(None)   // missing
    else:
      centroids.push(medianLat(pts), medianLng(pts))

  // interpolate missing
  centroids = interpolate(centroids)

  if count(None after interpolate) > 0.2 * routeBins: return None

  smoothed = movingAverage(centroids, window=3)
  simple = douglasPeucker(smoothed, 5)
  if bytes(simple) > 8192:
    simple = douglasPeucker(smoothed, 10)
    if bytes(simple) > 8192: return None
  return encodePolyline(simple, 5)
```

## Appendix B: ETA pseudocode

```
function eta(vehicle, targetStop, now):
  route = activeLearnedRoute or staticRoute
  if route is None:
    return distance(vehicle, targetStop) / defaultSpeedMps
  progress = snapToRoute(vehicle.lat, vehicle.lng, route)  // 0..1
  stops = stopsSortedByProgress(route, learnedStops)
  nextIdx = first i where stops[i].progress > progress
  if nextIdx is None: return None  // vehicle past target
  total = 0
  // partial current segment
  total += distanceAlongRoute(progress, stops[nextIdx].progress) / max(vehicle.paceMps, 1)
  // intermediate stops and segments
  for i in nextIdx .. indexOf(targetStop)-1:
    seg = segmentStats(line, dir, stops[i], stops[i+1], bucket(now))
    base = seg.p50 if seg and seg.count >= kMin else segGlobal.p50 if ... else dist/defaultSpeed
    histSpeed = distSeg / base
    factor = clamp(histSpeed / max(vehicle.paceMps,1), 0.5, 2.0)
    total += base * factor
    dwell = dwellStats(stops[i+1], bucket(now))
    total += dwell.p50 if dwell and dwell.count >= kMin else defaultDwellS
  return total
```

---

End of document.

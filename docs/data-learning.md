# Data Learning Plan: Route, Stops, Dwell, and ETA

Status: draft design document, scope [L], gated by D20. Light, in-process learning subsystem that consumes the existing trip-sharing event stream and produces de-identified aggregates for route geometry, stops, dwell times, segment travel times, and ETA prediction. Does not change alpha behavior. Nothing may be built before the legal gate in section 1 passes.

Companions: PLAN.md (5.5, 6, 7, 12, 13); DECISIONS.md (D02, D20, D30, D46); docs/privacy/inventory.md; docs/privacy/ripd.md.

Scope tags follow PLAN.md 0.2: [A] alpha, [A*] alpha should, [L] later. Everything here is [L] unless marked otherwise.

## 0. Purpose and status

Pontual serves live vehicle positions from rider pings plus static timetables and (for pilot lines) hand-recorded route polylines. This subsystem lets crowd-sourced trips teach the system: driven way-path per line as a polyline; stops actually served with dwell distributions by time of day, day of week, and date; real ETA/arrival prediction from current pace plus historic segment and stop data.

Deliberately light: no heavy ML framework, no per-fix DB writes, no raw track storage, no new runtime beyond the existing Deno API process. Reuses in-process event bus, existing pure domain layer, aggregate-only storage rule from D20.

Goals:
- Learn a centerline polyline per line and direction from accepted trip fixes, with confidence/sample count, served as versioned replacement for or fallback to static route file.
- Detect stops from repeated low-speed dwells, cluster into stable stop points, assign stable id and ordinal along route.
- Store dwell time statistics per stop by time bucket (15 min and hourly), day of week, rolling date window, with min/max/median and sample counts.
- Store segment travel time statistics between consecutive stops by same time buckets.
- Produce ETA predictions for a vehicle to downstream stops from current position, current pace, historic segment/stop stats.
- Produce next-bus arrival estimates at a stop from live vehicles plus historic headway.
- Keep privacy contract: no raw fixes, no device/trip ids, no client timestamps, trim trip ends, min group sizes, consent bump, RIPD update, lawyer review.

Non-goals: turn-by-turn navigation or point-to-point routing (PLAN.md 1.2); exact per-vehicle or per-driver profiling; real-time traffic from third parties; separate ML serving cluster in alpha (in-process; separate process later per PLAN.md 5.5); replacing static timetable (timetables stay static JSON, D07); learning from any source other than accepted fixes from consenting riders (no scraping/operator feeds, PLAN.md 7.5).

Success criteria: line with at least minRouteTrips (default 20) completed trips in a direction produces learned polyline with median distance to hand-recorded route (where exists) under 40 m; stop detection precision/recall >= 0.8 on manually labelled stops on two pilot lines; ETA median absolute error at 5 min horizon under 90 s on held-out week of simulator trips; prediction endpoints add <5 ms p99 to snapshot build time and no new per-fix DB write; privacy audit: no raw coordinate, device id, or trip id in any new table, log line, or metric (extends existing `no_location_at_rest` check).

## 1. Privacy and legal gate (D20)

Blocked until all done and recorded in DECISIONS.md:
1. Consent text version bump (new `consent_version`, e.g. 2) with explicit wording that de-identified, aggregated travel and dwell statistics may be derived from shared trips. Old consent version stays valid for live sharing only; aggregates updated only from trips whose rider consented to new version.
2. RIPD update in docs/privacy/ripd.md covering new processing purpose, aggregate data inventory, retention, re-identification risk.
3. Data inventory update in docs/privacy/inventory.md listing every new table and field.
4. Lawyer review of consent wording and aggregate schema before first byte stored.
5. Owner decision on whether aggregate publication is opt-in or part of base consent (recommendation: part of base consent v2, with separate opt-out toggle in settings that stops device from contributing without affecting live sharing).

Additional hard rules (PLAN.md 8 and 15):
- No raw per-trip tracks, ever. Only accumulators and cluster centroids.
- Trim first and last `trimEndsS` (default 120) seconds of every trip before aggregation.
- No device id, trip id, session id, or client timestamp in any aggregate row or event payload consumed by this subsystem.
- Minimum group size `kMin` (default 5 distinct trips) before an aggregate is published or served. Below `kMin`, withheld and client falls back to next coarser bucket or static data.
- Distinct-trip counting uses an in-memory, per-flush salted hash of a trip nonce discarded after flush. Nonce not persisted, cannot be joined back to a device.
- Aggregates keyed by line, direction, segment/stop, and time bucket only. Never by rider.
- Retention: rolling 90 days for segment/dwell stats; learned routes and stops persist until superseded by newer version, old versions kept 30 days for rollback.

## 2. High-level architecture

```
Trip sharing (existing): ping.ts / tick.ts
  -> EngineEvent bus (expanded)
  -> LearningConsumer (new, in-process): per-trip working state (memory only, discarded on TripEnded) + accumulator store (memory)
  -> periodic flush (every flushIntervalS, default 300)
  -> PostgreSQL aggregate tables (new migration)
  -> LearningReadModel (in-process cache, refreshed every cacheTtlS)
  -> HTTP/WS (new endpoints + optional snapshot fields)
  -> Flutter client (route/stops/ETA layers)
```

Key properties:
- Engine (`domain/`) stays pure and synchronous. Emits events only. Never imports learning module.
- Learning consumer is a stateful subscriber in server layer (`state/` or new `learning/` package), not in `domain/`.
- Working state for an in-flight trip lives only in memory and is dropped on `TripEnded`, including on crash. No recovery of in-flight learning state attempted.
- Database writes happen only in flush step, batched, upserts on aggregate keys.
- Serving reads from in-process cache refreshed from DB on TTL, so request paths never hit PostgreSQL for learning data.

New dir: `server/src/learning/` (consumer.ts, aggregator.ts, routeLearner.ts, stopDetector.ts, stats.ts, predictor.ts, cache.ts, types.ts). `domain/` gains only new event variants (section 3). No other change to pure layer.

## 3. Event contract expansion

Today `EngineEvent` has two variants: `vehicleUpdated: { lineId }`, `tripEnded: { lineId, reason }`.

Learning consumer needs fix-level progress without storing raw fixes. Add three variants; each carries only what an aggregate needs; no device id, no trip id beyond opaque in-memory token.

```ts
type EngineEvent =
  | { kind: "vehicleUpdated"; lineId: number }
  | { kind: "tripEnded"; lineId: number; tripKey: string; reason: EndReason }
  | { kind: "tripStarted"; lineId: number; tripKey: string; startedAtMs: number; lat: number; lng: number }
  | { kind: "fixAccepted"; lineId: number; tripKey: string; atMs: number; lat: number; lng: number; speedMps: number; heading: number | null; accuracyM: number }
  | { kind: "vehicleRemoved"; lineId: number; vehicleId: number };
```

Emission points (in `ping.ts`/`tick.ts`):
- `startTrip`: emit `tripStarted` with first fix. `tripKey` is fresh random UUID generated in server layer and held only in consumer's working map; engine never stores it.
- `applyPing` accepted fix: emit `fixAccepted`.
- `endTrip`: consumer finalises working state on `tripEnded` (already emitted). `tripEnded` must carry `tripKey` (change shape to include it). Internal event, not wire contract, safe. Consumer removes working state on receipt.

Privacy: `tripKey` never leaves process, never logged. Exists only to correlate fixes within one trip in memory.

Throttling: `fixAccepted` emitted for every accepted fix. Consumer downsamples to at most one sample per `minSampleSpacingM` (default 20 m) of travel or `minSampleSpacingS` (default 10 s), whichever comes first, before updating working state. Bounds memory and CPU.

## 4. Aggregation model and data structures

4.1 In-memory working state (per trip, discarded on end):

```ts
interface TripWork {
  tripKey: string;
  lineId: number;
  direction: number;        // 0 or 1, assigned at end
  consentVersion: number;   // only >= minConsentVersion contributes
  startedAtMs: number;
  samples: Array<{ t: number; lat: number; lng: number; speed: number }>;
  dwell: Array<{ lat: number; lng: number; startMs: number; endMs: number }>;
  totalDistanceM: number;
}
```

Rules:
- If `consentVersion < minConsentVersion` (default 2), consumer ignores trip entirely. No working state created.
- Samples trimmed: drop samples with `t < startedAtMs + trimEndsS*1000` and samples after `endedAtMs - trimEndsS*1000`.
- `samples` capped at `maxSamplesPerTrip` (default 200); excess uniformly downsampled.
- Memory budget: 200 trips * 200 samples * ~40 bytes ~ 1.6 MB plus overhead. Acceptable.

4.2 Accumulator store (in-memory, flushed periodically):

```ts
interface RouteAccumulator { lineId: number; direction: number; bins: Map<number, { latSum: number; lngSum: number; n: number }>; tripCount: number; lastFlushMs: number; }
interface StopCluster { lineId: number; direction: number; centroidLat: number; centroidLng: number; radiusM: number; passCount: number; samples: number; }
interface DwellAccumulator { stopId: string; hourBucket: number; dayOfWeek: number; count: number; sumS: number; minS: number; maxS: number; reservoir: number[]; }
interface SegmentAccumulator { lineId: number; direction: number; fromStop: string; toStop: string; hourBucket: number; dayOfWeek: number; count: number; sumS: number; minS: number; maxS: number; distanceM: number; reservoir: number[]; }
```

Accumulators flushed to PostgreSQL via upserts, then cleared from memory for flushed keys to bound memory. Counters representing lifetime sample counts are persisted and reloaded on startup, so flushing does not lose history.

4.3 Direction assignment:
- Compute vector from first kept sample to last kept sample.
- Compare against mean direction vector of existing accumulators for that line.
- If line has no accumulator yet, direction 0.
- If trip's vector within 60 degrees of an existing direction, assign that direction.
- Otherwise, if a second direction slot is free (max 2 directions per line), create direction 1.
- If neither fits, discard trip for route learning (likely detour/different service). Still contributes to dwell/segment stats only if it snaps to an existing stop sequence.
Max 2 directions per line is a simplification. Circular lines handled as single direction with progress wrapping at 1.0.

4.4 Consent gating: learning consumer receives `consentVersion` from trip start payload. Engine does not know consent versions; server handler calling `startTrip` looks up device's highest consent version and passes into event. If device has no consent row with version >= `minConsentVersion`, trip contributes nothing to learning. Live sharing unaffected.

## 5. Algorithms

5.1 Route learning (centerline):
Input: completed trips for (line, direction), each with ordered kept samples.

Step 1 per trip normalisation:
- Compute cumulative distance along trip's own samples using haversine.
- Let total = last cumulative. If total < minRouteLengthM (default 500 m), discard (too short, noise).
- For each sample, progress = cumulative / total in [0,1].
- Bin into routeBins (default 200) equal-width progress bins. For each bin, store median lat/lng of samples in that bin (median of lats and lngs independently). Removes within-trip jitter.

Step 2 cross-trip aggregation:
- For each bin index, collect per-trip median points.
- Bin centroid = median of those latitudes and longitudes.
- Require at least minRouteTrips (default 20) trips contributing to a bin before trusted. Missing bins interpolated linearly between nearest trusted bins. If more than 20% bins missing, route not published.

Step 3 smoothing and simplification:
- 3-point moving average along sequence of bin centroids.
- Douglas-Peucker at 5 m tolerance (reuse tools/route logic, ported to TypeScript in routeLearner.ts).
- Encode as polyline precision 5.
- Size check: <= 8 KB. If larger, increase tolerance to 10 m and retry; if still larger, reject publication.

Step 4 gating and versioning:
- Compute medianDeviationM between new polyline and currently published one (if any), sampled at 50 points. If deviation < 15 m, keep old version (no flapping).
- Otherwise insert new `learned_routes` row status `candidate`.
- Promote to `active` only after promotionTrips (default 10) additional trips agree within 20 m median. Avoids single bad week flipping route.
- Keep previous active version 30 days.

Cold start: if no static route and no learned route active, line has no polyline. Client draws nothing, as today.

5.2 Stop detection and clustering:
Per trip: walk kept samples. Dwell is maximal run where instantaneous speed (or smoothed speed over 3 samples) below stopSpeedMps (default 1.0 m/s) for at least minDwellS (default 10 s). Record centroid (median lat/lng of run) and duration. Drop dwells whose centroid within trimEndsS of trip start/end.

Cross-trip clustering (DBSCAN-like, at flush time): for each (line, direction), collect all dwell centroids from flush batch plus existing stop clusters. Cluster radius stopClusterRadiusM (default 30 m), min points stopMinPasses (default 4). Cluster reaching min becomes/updates `learned_stops` row; centroid = median of member centroids. Stop ordinal assigned by projecting each stop centroid onto active learned polyline (or static route if no learned) and sorting by cumulative distance. Cluster with no new pass for stopDecayDays (default 30) days marked `active = false`, retained 90 days.

Stop identity stability: cluster ids matched across flushes by nearest centroid within 40 m. If no match, new id minted. Ids are server-side UUIDs, not derived from location.

5.3 Dwell time statistics: hourBucket = floor(minute-of-day / 15) (0..95) for 15-min resolution, plus parallel hourly rollup. dayOfWeek = ISO day of week of dwell start in America/Sao_Paulo. dateBucket = ISO date of dwell start, stored only in daily rollup table and only when (stop, date) group reaches kMin (sparse; hourly/dow rollup is primary serving granularity).

Online accumulator update: find or create (stop, hourBucket, dayOfWeek) accumulator; update count, sum, min, max, reservoir (capped 64, reservoir sampling) for median. Median computed at flush from reservoir plus persisted reservoir via merge step, then reservoir reset.

Serving returns p50 and p90 (nearest-rank) plus count. If count < kMin, bucket withheld and client uses next coarser bucket (hour-of-day ignoring dow, then global stop median).

5.4 Segment travel time statistics: between consecutive stops along a trip's snapped stop sequence: for each pair of consecutive stops (A, B) actually served (both detected as dwells), travel time = B.startMs - A.endMs (excluding dwell at A, including running time); distance = polyline distance between A and B centroids. Accumulate per (line, direction, fromStop, toStop, hourBucket, dayOfWeek) as in 5.3. Also maintain global (line, direction, fromStop, toStop) accumulator ignoring time as fallback. Feeds ETA. Basis for future per-route-segment travel time by hour of week aggregate (D20).

5.5 ETA prediction: for a given vehicle and target downstream stop S:
1. Snap vehicle to active polyline (or static route). Compute progress p (0..1). If no route, fall back to straight-line distance / assumed speed.
2. Find next stop at progress > p (nextStop).
3. Remaining stops = stops from nextStop to S inclusive.
4. For each remaining segment between consecutive stops (Ai, Ai+1): look up segment stats for (line, direction, Ai, Ai+1, hourBucket, dayOfWeek); if count < kMin try (hourBucket only, any dow), then global. Base time = p50 of chosen bucket, or distance / defaultSpeedMps if none. Adjust by current pace: factor = clamp(histSpeed / currentSpeed, 0.5, 2.0), histSpeed = distance / baseTime, currentSpeed = max(vehicle.paceMps, 1 m/s). Adjusted = baseTime * factor. Add dwell at Ai+1 (p50 for that stop/bucket, or global stop median, or defaultDwellS).
5. Sum adjusted times. Add "current segment" partial: from vehicle position to nextStop using distance / currentSpeed (capped at 2x historic segment rate).
6. Return `{ etaS, confidence, sampleCount, method }`. Confidence "high" if all buckets used had count >= 2*kMin, "medium" if some fallback, "low" if mostly defaults.

Computed on demand in predictor.ts, cached 10 s per (vehicle, stop). Never stored.

Headway prediction (next bus at a stop): for target stop, find live vehicles downstream/upstream within window; for each compute ETA as above. If no live vehicle predicted within headwayHorizonS (default 1800 s), fall back to timetable: next scheduled departure + historic median travel time from terminus to stop. Return minimum ETA among candidates plus second-best for "following bus".

5.6 Model serving and update cadence:
- Route recompute: triggered when a (line, direction) accumulator reaches recomputeRouteEveryN (default 5) new trips since last recompute, or weekly by a job in `jobs/`. Runs in background task (Deno setTimeout/queue), never request path.
- Stop recompute: same trigger.
- Stats flush: every flushIntervalS (default 300 s) or when an accumulator exceeds flushThresholdRows (default 1000).
- Read model cache: refreshed every cacheTtlS (default 60 s) from DB, or immediately after flush completes.
- All recompute best-effort; failures logged (without coordinates) and retried next cycle.

## 6. Persistence schema (new migration)

Migration file: `server/db/migrations/0003_learning.sql` (number after last existing). Forward-only. Grants to `pontual_app` limited to new tables.

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
- `learned_stops.lat/lng` are aggregate centroids. They are the only location at rest introduced by this subsystem and permitted because they are not individual locations. The `no_location_at_rest` check must be updated to allow these specific columns and keep rejecting everything else.
- No device id, trip id, or client timestamp column exists in any table.
- Daily rollup table omitted from v1 to keep group sizes meaningful; add `stop_dwell_daily` only if a later review shows sufficient volume.

## 7. Serving API

All new endpoints are public reads (no auth), consistent with vehicle reads (PLAN.md 6.5). Rate limits per IP.

7.1 `GET /v1/lines/:id/learned-route`:
Response:
```json
{ "v": 3, "dir": 0, "polyline": "_p~iF~ps|U...", "points": 142, "trips": 47, "computed_at": "2026-10-20T12:00:00Z", "fallback": false }
```
- `v` is `learned_routes.version`.
- If no active learned route: 200 with `fallback: true` and static route polyline from server data bundle; if no static route either, `polyline` null. (Recommendation over 204.)
- `ETag` based on version; `Cache-Control: public, max-age=300`.
- Rate limit 60/min/IP.

7.2 `GET /v1/lines/:id/stops`:
Response:
```json
{ "dir": 0, "stops": [ { "id": "uuid", "i": 0, "lat": -18.72, "lng": -39.85, "r": 30, "n": 41 } ], "fallback": false }
```
- `i` is ordinal along route; `n` is `sample_passes`.
- If no learned stops: static stops for that line from server data bundle with `fallback: true` and no `n`.
- `Cache-Control: public, max-age=300`.

7.3 `GET /v1/lines/:id/eta`:
Query: `stop` (uuid, required), optional `vehicle` (vehicle id from snapshot to scope to one bus). If `vehicle` omitted, returns ETAs for all live vehicles on the line to that stop.

Response:
```json
{ "stop": "uuid", "now": 1730000000, "items": [ { "vehicle": 12, "eta_s": 240, "conf": "high", "n": 38 }, { "vehicle": 15, "eta_s": 720, "conf": "medium", "n": 12 } ], "next_scheduled_s": 900 }
```
- `next_scheduled_s` from timetable when live estimate not available or beyond `headwayHorizonS`.
- Rate limit 120/min/IP (matches vehicle reads).
- Computed on demand with 10 s cache per (line, stop).

7.4 Optional snapshot field: vehicle snapshot `v` array could gain trailing `eta_next_stop_s` for vehicle's next stop. Wire contract change, additive only; app parses by index today, so adding breaks old clients unless updated first. Recommendation: do not add to snapshot; use dedicated ETA endpoint and let client poll. Revisit after two releases.

7.5 Client data flow:
- `LearnedRouteRepository` and `LearnedStopsRepository` in `data/` fetch and cache learned route/stops with ETag revalidation, mirroring `VehicleRepository`. Cached on disk with 1 h TTL and stale-while-revalidate.
- `EtaRepository` polls `/v1/lines/:id/eta` for selected stop every 30 s when line detail screen open.
- Map layer: draw learned polyline if available, else static route, else none. Draw learned stops as dots with tap showing ETA.
- Stop layer decorative until learned stops exist; no stop picker (D83). Selection of target stop for ETA uses nearest learned stop to user's tap, snapped to route.

## 8. Client changes summary

- New repositories in `data/`: `learned_route_repository.dart`, `learned_stops_repository.dart`, `eta_repository.dart`.
- New models in `domain/` (pure Dart): `LearnedRoute`, `LearnedStop`, `EtaEstimate`. No Flutter imports.
- Map screen: polyline source selection (learned -> static -> none), stop dots, ETA bottom sheet.
- Settings: "Contribute anonymous trip statistics" toggle (default on if consent v2 accepted). Opt-out calls new `DELETE /v1/me/learning` endpoint that removes device from future contribution; since no device id stored, implemented by recording opt-out flag on device row and checking it at trip start. Flag deleted with device.
- Strings: all new UI strings in `ui_strings.dart`, pt-BR.

No change to trip sharing, battery, or foreground service logic. `TripController` remains the only place that starts/stops the service.

## 9. Configuration and tunables

Add to `app_config` (validated, defaults in code):

| Key | Default | Meaning |
| --- | --- | --- |
| `learning_enabled` | `false` | master kill switch for whole subsystem |
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

Client-side fallback constants mirror these but server value always wins (PLAN.md 7, architecture rules).

## 10. Privacy controls and k-anonymity

- `kMin` applies to every served aggregate. Below it, withhold and fall back.
- Additional suppression: if a (stop, hour, dow) bucket has count >= kMin but the stop has fewer than `minDistinctDays` (default 3) distinct dates contributing, withhold, to prevent single-day identification.
- Distinct-trip counting uses a per-flush salted hash of a trip nonce discarded after flush. No join key persists.
- Aggregates never include origin/destination trimming beyond `trimEndsS`; if a line has only one stop cluster (terminus), suppress dwell stats there to avoid home inference. Actually suppress the first and last stop's dwell stats entirely, since terminus dwell reveals rider boarding/alighting patterns. Only intermediate stops get dwell stats.
- Route polyline is an aggregate of many trips; individual trips cannot be recovered. Still, apply minimum of `minRouteTrips` before publishing.
- Logs: learning module uses existing `Log` wrapper, which has no API accepting coordinates. Add lint rule / test that greps new files for coordinate-like logging.
- Metrics: counters only (trips contributed, flushes, cache hits). No coordinates, no ids, no per-line counts below kMin (report "lines with data" only as a boolean per line).

## 11. Retention and deletion

- `segment_stats` and `stop_dwell_stats`: rolling 90 days. Daily job deletes rows whose `updated_at < now() - 90 days`. Counts decremented; if a (key) loses all rows it is removed.
- `learned_routes`: keep active + previous for 30 days; delete retired older than 30 days.
- `learned_stops`: keep inactive for 90 days, then delete, cascading to stats.
- `learning_watermarks`: no expiry; tiny.
- `DELETE /v1/me` (existing) cascades device rows; since no learning row references a device, nothing extra needed, but opt-out flag goes with device.
- `DELETE /v1/me/learning` sets opt-out flag; future trips from that device do not contribute. Past aggregates are not recomputed (cannot be attributed).

## 12. Performance and resource budgets

- No per-fix database writes. Flush batched every 5 min.
- Working state memory cap: 50 MB. If exceeded, new trips not tracked for learning (live sharing unaffected) and a counter incremented.
- Recompute runs in background task with 30 s time budget; if exceeds, abort and retry next cycle.
- Read model cache refresh incremental (only changed rows since `last_refresh_at`).
- CPU: learning adds at most 5% overhead to ping path (measured by existing perf harness).
- Deno permissions unchanged: no new `--allow-write`/`run`/`ffi`.

## 13. Testing strategy

Unit (Deno, pure functions, no DB):
- `routeLearner`: centerline on synthetic trips recovers known polyline within 5 m; trimming drops endpoints; direction assignment; simplification size budget.
- `stopDetector`: synthetic dwell runs produce clusters; noise dwells below min duration dropped; terminus suppression.
- `stats`: accumulator upserts, reservoir median, kMin withholding, fallback chain.
- `predictor`: ETA on known route with known stats returns expected value within 1%; fallback to defaults when no stats.

Integration (against test PostgreSQL, as existing security suite):
- Flush writes only aggregate rows; `no_location_at_rest` extended asserts no raw fix columns exist and no row contains a coordinate outside set of known stop/route centroids.
- Consent gating: trips with consent v1 do not increment any counter.
- Opt-out: flagged device's trips do not contribute.
- kMin: buckets below threshold are not served (404/empty + fallback).
- Migration applies cleanly and rolls back.

Property/fuzz:
- Aggregator never throws on empty trips, single-sample trips, or zero-distance trips.
- Predictor never returns negative ETA.

Privacy audit:
- Grep learning files for coordinate logging; CI check.
- DB dump inspection in tests: column allow-list per table.

## 14. Milestones and tasks

Phase 0, spikes (before any code):
- S-L1: map-match-free centerline quality on simulator trips. Small offline script in `tools/` runs route algorithm on simulator output and reports deviation vs input route. Gate: median < 40 m on two lines.
- S-L2: consent wording and RIPD review with owner's lawyer. Gate: written approval.
- S-L3: group-size feasibility: run simulator for week-equivalent and check intermediate-stop buckets reach kMin. If not, raise kMin lowering or accept sparser data.
- S-L4: performance: recompute on 10k trips in < 30 s.

Phase 1, event plumbing and in-memory aggregator (no DB, no serving):
- T-L1: expand `EngineEvent` variants and emission points.
- T-L2: implement `learning/consumer.ts` with working state and downsampling.
- T-L3: implement accumulators and flush to no-op sink; add tests.
- T-L4: consent gating and opt-out flag on devices (migration 0003 partial: add `learning_opt_out boolean` to devices? Actually keep separate `device_learning_opt_outs` table or a column. Recommendation: add column `learning_opt_out boolean not null default false` to `devices` via migration 0003. Simpler and cascades on delete.)

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

Each task is one logical change set, with acceptance criteria and tests, per PLAN.md 0.3 and 16.

## 15. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Low rider volume -> buckets never reach kMin | No learned data served | Fall back to static route/stops/timetable; keep collecting; lower kMin only after S-L3 |
| Route changes (construction, detours) | Stale polyline | Decay and recompute weekly; candidate/promotion gate prevents flapping; manual invalidation via app_config |
| Direction misclassification on circular lines | Mixed samples corrupt centerline | Single direction for circulars; detect by start/end proximity |
| Re-identification via rare (stop, hour, dow) buckets | Privacy breach | kMin + distinct-days suppression + terminus suppression; lawyer review |
| Memory blowup on busy days | Process OOM | 50 MB cap; drop learning tracking, keep live sharing |
| Recompute CPU spikes | Latency | Background task with 30 s budget; abort and retry |
| Learned route worse than static | Bad UX | Median-deviation gate; keep static as fallback; manual rollback via version |
| Consent confusion | Legal | Separate opt-out toggle; clear wording; version bump |
| Migration risk on production | Downtime | Forward-only; test on staging; owner runs migration per runbook |

## 16. Open decisions for the owner

1. Opt-in vs. opt-out for contributing aggregates (recommendation: opt-out toggle, default on, only after consent v2).
2. Whether learned routes should auto-replace static routes in the client or require a manual "use community route" toggle (recommendation: auto-replace when confidence high, with a "report wrong route" link).
3. Whether to expose ETA publicly or only to consenting riders (recommendation: public, since it is aggregate and contains no rider data).
4. Max directions per line: 2 (recommendation) vs. N.
5. Whether to store a daily rollup table (recommendation: defer until volume justifies).
6. Whether model serving should move to a separate process (recommendation: defer; in-process is fine until CPU budget is hit).


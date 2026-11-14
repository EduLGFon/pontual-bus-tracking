# Learning verification (read-only)

Read-only checks for diagnosing missing learned routes (e.g. line 66). Run inside the DB container or via psql with the migrator role. No coordinates, tokens or device identifiers returned.

## Schema migrations

```sql
select version from schema_migrations order by version;
```

Learning accumulators introduced in `0006_learning_accumulators`. A missing latest migration explains missing tables.

## app_config learning overrides

```sql
select key, value from app_config
where key like 'learning_%'
order by key;
```

Check `learning_enabled` and `learning_flush_interval_s` (default 300). Old `learning_min_route_trips`, `learning_min_trip_route_m`, `learning_min_stop_passes`, `learning_k_min` keys are no longer read.

## Learned routes for line 66

```sql
select line_id, direction, version, status, sample_trips, point_count, computed_at
from learned_routes where line_id = 66 order by direction, version;
```

No rows: no route published for that line. A route publishes after the first contributing trip. `sample_trips` is the cumulative confidence count for that direction.

## Route accumulator state

```sql
select line_id, direction, sample_trips, last_publish_at
from learning_route_state where line_id = 66 order by direction;

select direction, count(*) as cells, sum(trips) as cell_trips
from learning_route_cells where line_id = 66 group by direction order by direction;

select direction, count(*) as edges, sum(trips) as edge_trips
from learning_route_edges where line_id = 66 group by direction order by direction;
```

`sample_trips` stored in PostgreSQL and survives restarts. If greater than active route's `sample_trips`, publication is behind: check API log for learning flush failures, then wait for next flush or restart API to trigger stale-route safety net.

## Learned stops and histograms

```sql
select direction, count(*) as stops,
       count(*) filter (where active) as active_stops,
       sum(sample_passes) as passes
from learned_stops where line_id = 66 group by direction order by direction;

select count(*) as dwell_bins, sum(sample_count) as dwell_samples
from learning_dwell_bins b
join learned_stops s on s.id = b.stop_id
where s.line_id = 66;

select count(*) as travel_bins, sum(sample_count) as travel_samples
from learning_travel_bins where line_id = 66;
```

Stops created on first dwell. Bins cumulative; missing bin means that stop, bucket or duration not observed yet.

## Opt-out devices

```sql
select count(*) as devices,
       count(*) filter (where learning_opt_out) as opted_out
from devices;
```

Aggregate only. Opt-out reduces future contributions but does not remove existing aggregates, which cannot be attributed to a device.

## Device and volume creation times

```sql
select min(created_at) as first_device, max(created_at) as last_device from devices;
```

Compare with container migration date. Recent `first_device` indicates a fresh database volume.

## Interpreting outcomes

- Fresh database: no `devices`, no `learned_routes`, recent `first_device`. Cause: old host database not restored into container volume.
- No route but route state exists: active route missing, or chain has fewer than 2 points, or polyline exceeded 8192-char cap. Stops can still be published and served.
- Route state ahead of active route: a trip committed cells and state but process died before async publication. Next flush or restart republishes.
- No cells at all: no consenting trip produced a valid cell transition for that line/direction, or subsystem disabled.
- Cumulative counts grow slowly: normal for small rider volume. No minimum trip gate; a single trip is enough to publish.

Logs and metrics are process-lifetime only and cannot reconstruct a past trip after a restart.
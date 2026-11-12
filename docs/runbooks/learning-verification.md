# Learning verification (read-only)

Read-only checks for diagnosing missing learned routes (for example line 66).
Run inside the database container or via psql with the migrator role. No
coordinates, tokens, or device identifiers are returned by these queries.

## Schema migrations

```sql
select version from schema_migrations order by version;
```

A missing latest migration explains missing tables. A present latest migration
with empty data points at a fresh volume or a process reset, not a code bug.

## app_config learning overrides

```sql
select key, value from app_config
where key in ('learning_enabled','learning_min_route_trips','learning_flush_interval_s')
order by key;
```

Check `learning_min_route_trips` (default 5) and `learning_flush_interval_s`
(default 300). Overrides here change the publish gate and flush cadence.

## learned routes for line 66

```sql
select line_id, direction, version, status, sample_trips, point_count, computed_at
from learned_routes where line_id = 66 order by direction, version;
```

No rows: no route has ever published for that line. Active rows with
`sample_trips` show the last published corridor trip count.

## learning watermarks per direction

```sql
select line_id, direction, trips_since_route_recompute, last_flush_at
from learning_watermarks where line_id = 66 order by direction;
```

Watermarks are cumulative across process restarts; they are not restored into
the in-memory corridor accumulator.

## devices learning trips and opt-out

```sql
select count(*) as devices, count(*) filter (where learning_trips >= 5) as eligible,
       count(*) filter (where learning_opt_out) as opted_out
from devices;
```

Aggregate only. A low eligible count means few devices have reached the
five-trip gate.

## device and volume creation times

```sql
select min(created_at) as first_device, max(created_at) as last_device from devices;
```

Compare with the container migration date. Recent `first_device` values indicate
a fresh database volume.

## Interpreting outcomes

- Fresh database: no `devices`, no `learned_routes`, recent `first_device`.
  Cause: the old host database was not restored into the container volume.
- Process reset: watermarks and learned routes exist, but no new route publishes
  until 5 corridor-contributing trips occur in one API process. Cause: deploy or
  restart cleared the in-memory accumulator.
- Publish gate: `learned_routes` absent but watermarks present and devices
  eligible. Cause: fewer than `learning_min_route_trips` trips in one process,
  or chain too small / route too short / oversized / no-flap suppressed.

Logs and metrics are process-lifetime only and cannot reconstruct a past trip
after a restart.

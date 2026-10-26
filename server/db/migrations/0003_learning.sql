-- 0003_learning.sql: de-identified aggregates for the learning subsystem.
-- See docs/data-learning.md. Forward-only; never edit after merge.
-- Location exists only as aggregate centroids (stops) and learned routes,
-- never as per-trip fixes. See PLAN.md D02 and D20.

-- migrate:up

alter table devices
  add column if not exists learning_opt_out boolean not null default false;

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
alter table devices drop column if exists learning_opt_out;
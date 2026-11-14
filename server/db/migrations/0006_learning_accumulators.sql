-- 0006_learning_accumulators.sql: DB-backed learning accumulators.
-- Replaces the process-local corridor progress and the per-device eligibility
-- counter. Only aggregate cells, edges, trip counts and histograms live here:
-- no raw fixes, no device ids, no trip ids, no client timestamps.
-- Cell centroids are aggregate means of accepted fixes in a fixed-size grid
-- cell, never an individual location. See docs/data-learning.md and D98.
-- Forward-only; never edit after merge.

-- migrate:up

create table if not exists learning_route_cells (
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
create index if not exists learning_route_cells_line_dir_idx
  on learning_route_cells (line_id, direction);
comment on table learning_route_cells is
  'aggregate-only corridor grid cells; no raw fixes or per-trip tracks';
comment on column learning_route_cells.trips is
  'number of contributing trips that crossed this cell; never a device or trip id';
comment on column learning_route_cells.lat is
  'weighted centroid of the grid cell across contributing trips; aggregate only';
comment on column learning_route_cells.lng is
  'weighted centroid of the grid cell across contributing trips; aggregate only';

create table if not exists learning_route_edges (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  from_cell text not null,
  to_cell text not null,
  trips integer not null default 0 check (trips >= 0),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (line_id, direction, from_cell, to_cell)
);
create index if not exists learning_route_edges_line_dir_idx
  on learning_route_edges (line_id, direction);
comment on table learning_route_edges is
  'aggregate-only directed cell transitions; no raw fixes or per-trip tracks';

create table if not exists learning_route_state (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  sample_trips integer not null default 0 check (sample_trips >= 0),
  last_publish_at timestamptz,
  primary key (line_id, direction)
);
comment on table learning_route_state is
  'aggregate-only per-direction trip count and last publication attempt';
comment on column learning_route_state.sample_trips is
  'contributing trips accumulated across processes; confidence, not eligibility';

create table if not exists learning_dwell_bins (
  stop_id uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  bin_s smallint not null check (bin_s >= 0),
  sample_count integer not null default 0 check (sample_count >= 0),
  primary key (stop_id, hour_bucket, day_of_week, bin_s)
);
comment on table learning_dwell_bins is
  'aggregate-only dwell histogram bins; no raw fixes or per-trip tracks';

create table if not exists learning_travel_bins (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  from_stop uuid not null references learned_stops(id) on delete cascade,
  to_stop uuid not null references learned_stops(id) on delete cascade,
  hour_bucket smallint not null check (hour_bucket between 0 and 95),
  day_of_week smallint not null check (day_of_week between 0 and 6),
  bin_s smallint not null check (bin_s >= 0),
  sample_count integer not null default 0 check (sample_count >= 0),
  primary key (
    line_id, direction, from_stop, to_stop, hour_bucket, day_of_week, bin_s
  )
);
comment on table learning_travel_bins is
  'aggregate-only segment travel histogram bins; no raw fixes or per-trip tracks';

grant select, insert, update, delete on learning_route_cells to pontual_app;
grant select, insert, update, delete on learning_route_edges to pontual_app;
grant select, insert, update, delete on learning_route_state to pontual_app;
grant select, insert, update, delete on learning_dwell_bins to pontual_app;
grant select, insert, update, delete on learning_travel_bins to pontual_app;

drop table if exists learning_watermarks;

alter table devices drop column if exists learning_trips;

-- migrate:down

alter table devices
  add column if not exists learning_trips integer not null default 0
  check (learning_trips >= 0);
comment on column devices.learning_trips is
  'count of started trips eligible for learning; pseudonymous counter, no location';

create table if not exists learning_watermarks (
  line_id integer not null,
  direction smallint not null check (direction in (0,1)),
  trips_since_route_recompute integer not null default 0,
  trips_since_stop_recompute integer not null default 0,
  last_flush_at timestamptz,
  primary key (line_id, direction)
);
grant select, insert, update, delete on learning_watermarks to pontual_app;

drop table if exists learning_travel_bins;
drop table if exists learning_dwell_bins;
drop table if exists learning_route_state;
drop table if exists learning_route_edges;
drop table if exists learning_route_cells;

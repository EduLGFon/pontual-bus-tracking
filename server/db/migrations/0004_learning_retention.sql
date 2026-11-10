-- 0004_learning_retention.sql: retention cleanup for the learning subsystem.
-- Forward-only; never edit after merge. See docs/data-learning.md section 11.
-- migrate:up

-- Retention is enforced by the API's daily purge job (jobs.ts), not by
-- triggers, so this migration only documents the policy and ensures indexes
-- exist for efficient deletes.

create index if not exists learned_routes_retired_idx
  on learned_routes (status, retired_at) where status = 'retired';
create index if not exists learned_stops_inactive_idx
  on learned_stops (active, last_seen_at) where active = false;
create index if not exists segment_stats_updated_idx
  on segment_stats (updated_at);
create index if not exists stop_dwell_stats_updated_idx
  on stop_dwell_stats (updated_at);

grant select, insert, update, delete on learned_routes to pontual_app;
grant select, insert, update, delete on learned_stops to pontual_app;
grant select, insert, update, delete on segment_stats to pontual_app;
grant select, insert, update, delete on stop_dwell_stats to pontual_app;

-- migrate:down
drop index if exists learned_routes_retired_idx;
drop index if exists learned_stops_inactive_idx;
drop index if exists segment_stats_updated_idx;
drop index if exists stop_dwell_stats_updated_idx;
-- 0002_diagnostics.sql: optional first-party diagnostic bundles.
-- Anonymous (no coordinates, no device identifiers beyond the hashed token
-- linkage which cascades on device deletion). Retention: 14 days.
-- See DECISIONS.md (diagnostics ADR).

-- migrate:up
create table if not exists diagnostics (
  id uuid primary key default gen_random_uuid(),
  device_id uuid references devices(id) on delete cascade,
  created_at timestamptz not null default now(),
  payload jsonb not null
);
comment on table diagnostics is 'redacted diagnostic bundles, no PII, 14-day retention';
create index if not exists diagnostics_created_idx on diagnostics (created_at);
create index if not exists diagnostics_device_idx on diagnostics (device_id);

grant select, insert, delete on diagnostics to pontual_app;

-- migrate:down
drop table if exists diagnostics;
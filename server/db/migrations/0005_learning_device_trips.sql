-- 0005_learning_device_trips.sql: per-device learning eligibility counter.
-- Pseudonymous counter only; no location. A device with at least 5 started
-- trips unlocks learning aggregates. See DECISIONS.md#D98.
-- Forward-only; never edit after merge.

-- migrate:up

alter table devices
  add column if not exists learning_trips integer not null default 0
  check (learning_trips >= 0);
comment on column devices.learning_trips is 'count of started trips eligible for learning; pseudonymous counter, no location';

-- migrate:down
alter table devices drop column if exists learning_trips;

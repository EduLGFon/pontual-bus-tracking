-- 0001_init.sql: durable pseudonymous data only. No location at rest.
-- See ARCHITECTURE.md 6.4. Forward-only; never edit after merge.
-- Roles: pontual_migrator owns schema (used by dbmate); pontual_app is the
-- only credential in DATABASE_URL with least privilege on these four tables.

-- migrate:up
-- Extensions needed for gen_random_uuid.
create extension if not exists pgcrypto;

-- Application role for the running API. No superuser, no createdb.
-- Password is set outside this migration (env/runbook/T04). Local and CI
-- use a test password via TEST_DATABASE_URL setup, never committed here.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'pontual_app') then
    create role pontual_app with login;
  end if;
end
$$;

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  -- SHA-256 hash of the opaque device token. 32 bytes exactly.
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);
comment on table devices is 'pseudonymous device rows only, no location';
create index if not exists devices_expires_idx on devices (expires_at);

create table if not exists consents (
  device_id uuid not null references devices(id) on delete cascade,
  version smallint not null,
  accepted_at timestamptz not null default now(),
  primary key (device_id, version)
);

create table if not exists blocked_devices (
  device_id uuid primary key references devices(id) on delete cascade,
  reason text,
  blocked_at timestamptz not null default now()
);

create table if not exists app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
comment on table app_config is 'runtime tunables, JSON values, reloaded every 30 s';

-- Least privilege for the running API. No CREATE, no superuser.
grant select, insert, update, delete on devices to pontual_app;
grant select, insert, update, delete on consents to pontual_app;
grant select, insert, update, delete on blocked_devices to pontual_app;
grant select, insert, update, delete on app_config to pontual_app;

-- migrate:down
drop table if exists app_config;
drop table if exists blocked_devices;
drop table if exists consents;
drop table if exists devices;

# Docker deployment (D101, D102)

Compose stack (`server/deploy/compose.yaml`) runs four services:

- `db`: pinned `postgres:18.6`, named volume, internal `data` network only.
- `migrate`: one-shot `amacneil/dbmate:2.36.0` applying forward-only migrations in `server/db/migrations/`.
- `api`: image from `server/deploy/Dockerfile`, on internal `edge` + `data` networks, no published port.
- `cloudflared`: `cloudflare/cloudflared:2026.11.0`, on internal `edge` + non-internal `egress`, outbound-only tunnel.

Networks: `edge` internal (`api`+`cloudflared`); `data` internal (`api`+`db`+`migrate`); `egress` non-internal (`cloudflared` only).

Static data built inside the API image from `data/` and `tools/`. No secret in any image.

## Prerequisites

- Docker Engine + Compose v2.
- Locally managed Cloudflare Tunnel named `pontual`. Ingress rules in mounted config; public hostname `api-pontual.spotnik.space` (optional `api.pontual.spotnik.space`) points at `http://api:8080`. Web origin `https://pontual.spotnik.space`.

## Environment

Three secret sources keep credentials out of the API container and git:

| File | Used by | Contents |
| --- | --- | --- |
| `server/.env` | `api` | `APP_ENV`, `DATABASE_URL` (app role), origins, log level |
| `server/.env.db` | `db`, `migrate` | `POSTGRES_PASSWORD`, `PONTUAL_APP_PASSWORD` |
| `server/secrets/cloudflared.yml` | `cloudflared` | tunnel config (non-secret), readable |
| `server/secrets/cloudflared_credentials.json` | `cloudflared` | tunnel credentials, uid 65532 mode 0400 |

Copy examples, generate hex passwords, keep `PONTUAL_APP_PASSWORD` identical to the password in `DATABASE_URL`:

```sh
test -f server/.env || cp server/.env.docker.example server/.env
test -f server/.env.db || cp server/.env.db.example server/.env.db
chmod 600 server/.env server/.env.db
openssl rand -hex 32   # migrator password -> server/.env.db POSTGRES_PASSWORD
openssl rand -hex 32   # app password -> PONTUAL_APP_PASSWORD and DATABASE_URL
```

Tunnel config non-secret world-readable `0644`/`0444` or owner uid 65532 owner-read; credentials JSON uid 65532 mode 0400. Config's `credentials-file` must be `/run/secrets/cloudflared_credentials`. Never put secrets in compose, env examples, git, logs or docs.

```sh
install -d -m 700 server/secrets
cp server/deploy/cloudflared/config.example.yml server/secrets/cloudflared.yml
chmod 644 server/secrets/cloudflared.yml
# replace placeholder tunnel UUID with real one from `cloudflared tunnel list`
# (or TunnelID field of credentials JSON)
# place credentials JSON from `cloudflared tunnel create pontual`, then:
sudo chown 65532:65532 server/secrets/cloudflared_credentials.json
sudo chmod 400 server/secrets/cloudflared_credentials.json
```

Compose preserves ownership/mode inside container. A host service bound to loopback is not reachable through `host.docker.internal`; attach tunnel container to that service's Docker network with override, or use a bridge-reachable address.

Hex avoids URL-encoding problems: Compose builds the migrator URL from `POSTGRES_PASSWORD`, and `DATABASE_URL` embeds the app password.

`PONTUAL_ENV_FILE`, `PONTUAL_DB_ENV_FILE`, `PONTUAL_TUNNEL_CONFIG_FILE`, `PONTUAL_TUNNEL_CREDENTIALS_FILE` are read by Compose interpolation from shell (or `.env` next to compose file), not from `server/.env`. Both env files default to paths next to compose file. For root-owned files, point variables at them:

```sh
PONTUAL_ENV_FILE=/etc/pontual/api.env \
PONTUAL_DB_ENV_FILE=/etc/pontual/db.env \
PONTUAL_TUNNEL_CONFIG_FILE=/etc/pontual/cloudflared.yml \
PONTUAL_TUNNEL_CREDENTIALS_FILE=/etc/pontual/cloudflared_credentials.json \
  docker compose -f server/deploy/compose.yaml up -d
```

Compose sets `HOST=0.0.0.0`, `PORT=8080`, `DATA_DIR=/app/build` and a loopback `METRICS_PORT` inside the API container. Do not override `HOST` to a public interface: API is not published.

`DATABASE_URL` must use `db:5432` for bundled database. Stack self-contained: API has no internet egress, requires bundled database.

## Build and run

From repo root:

```sh
docker compose -f server/deploy/compose.yaml up -d --build
```

`up` starts `db`, waits healthcheck, runs `migrate`, waits exit success, then starts `api` and `cloudflared`. Check from inside containers (no host port):

```sh
docker compose -f server/deploy/compose.yaml ps
docker compose -f server/deploy/compose.yaml logs --tail=100 migrate
docker compose -f server/deploy/compose.yaml logs --tail=100 api
docker compose -f server/deploy/compose.yaml exec -T api deno eval --quiet --no-config --allow-net=127.0.0.1:8080 'const r = await fetch("http://127.0.0.1:8080/v1/health"); if (!r.ok) Deno.exit(1);'
docker compose -f server/deploy/compose.yaml exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready
```

`migrate` must show `Exited (0)`. API healthcheck calls `/v1/health` from inside container.

## Database

Reachable only from compose network; no host port mapping. Open session through container:

```sh
docker compose -f server/deploy/compose.yaml exec db \
  psql -U pontual_migrator -d pontual
```

Role model (ARCHITECTURE.md 6.4): `pontual_migrator` owns schema, used only by `migrate`. `pontual_app` has SELECT/INSERT/UPDATE/DELETE on app tables, only credential in API `DATABASE_URL`.

First start creates self-signed cert in DB volume, appends `ssl=on` to `postgresql.conf`. `pg_hba.conf` switched to `hostssl`; cleartext TCP rejected. Clients use `sslmode=require` (encrypts without verifying self-signed). Unix socket inside container remains available to psql and healthcheck.

Named volume is only persistent state:

```sh
docker volume ls | grep pontual-db
```

Back up with `pg_dump` per `docs/runbooks/ops.md`. Never run `docker compose down -v` unless data intentionally destroyed.

### Upgrading PostgreSQL 16 to 18

PG 18 changed image layout: `PGDATA` is `/var/lib/postgresql/18/docker`, volume mounted at `/var/lib/postgresql`, not `/var/lib/postgresql/data`. Old 16 volume mounted directly at `/var/lib/postgresql/data`, so its files are the volume root. After new mount they appear at `/var/lib/postgresql/PG_VERSION`, `/var/lib/postgresql/base`, etc., not under `data/`. 18 cluster created beside them in `/var/lib/postgresql/18/docker`. Major format incompatible; 18 cannot start old files.

Preflight in `deploy.sh` detects `PG_VERSION` at volume root and prints migration hint when 18 cluster empty/unqueryable. Does not block a successfully restored cluster. Do not use `PONTUAL_ALLOW_EMPTY_DB=1` to skip migration.

1. Dump running 16 DB before changing stack. Keep stack up; `pg_dump` reads over container local socket.

```sh
mkdir -p /var/backups/pontual
docker compose -f server/deploy/compose.yaml exec -T db \
  pg_dump -U pontual_migrator -d pontual -Fc \
  > /var/backups/pontual/pontual-pg16-$(date +%Y%m%dT%H%M%S).dump
sha256sum /var/backups/pontual/*.dump
```

If stack already stopped, dump from temporary 16 container; volume root is old data dir:

```sh
docker run --rm -d --name pontual-pg16 \
  -v pontual-api_pontual-db:/var/lib/postgresql \
  -e PGDATA=/var/lib/postgresql \
  postgres:16.15
docker exec pontual-pg16 pg_dump -U pontual_migrator -d pontual \
  -Fc -f /tmp/pontual.dump
docker cp pontual-pg16:/tmp/pontual.dump \
  /var/backups/pontual/pontual-pg16.dump
docker stop pontual-pg16
```

2. Stop old stack and start 18. Keep volume. Init script recreates roles and TLS material in new cluster.

```sh
docker compose -f server/deploy/compose.yaml stop api cloudflared migrate db
docker compose -f server/deploy/compose.yaml up -d db
```

3. Restore. New `pontual` DB empty; dump carries schema/data/grants.

```sh
docker compose -f server/deploy/compose.yaml exec -T db \
  pg_restore -U pontual_migrator -d pontual --clean --if-exists \
  < /var/backups/pontual/pontual-pg16-YYYYmmddTHHMMSS.dump
```

4. Deploy normally. Preflight should report non-zero device and route count. If `schema_migrations` came from dump, dbmate reports no pending migrations; otherwise `migrate` applies rest. Verify:

```sh
docker compose -f server/deploy/compose.yaml exec -T db \
  psql -U pontual_migrator -d pontual -c \
  "select (select count(*) from devices) as devices,
          (select count(*) from learned_routes) as routes;"
```

Keep dump and old files at volume root until restore and API health verified. To roll back: stop stack, run 16 container with volume at `/var/lib/postgresql` and `PGDATA=/var/lib/postgresql`, then restore old compose mount. Do not delete old files until 18 deployment stable for agreed window. `pg_upgrade --link` with `tianon/postgres-upgrade:16-to-18` is alternative; dump/restore above is supported path. Procedure not executed against VPS in this change.

## Migrations

Apply automatically on `up`. dbmate runs migrator role, points at read-only `server/db/migrations/` mount, uses `--no-dump-schema`.

Run one-shot service again without touching API:

```sh
docker compose -f server/deploy/compose.yaml run --rm migrate
```

Or dbmate manually with migrator URL:

```sh
DATABASE_URL='postgresql://pontual_migrator:...@db:5432/pontual?sslmode=require' \
  dbmate -d server/db/migrations up
```

Forward-only and backward compatible for one release (ARCHITECTURE.md 17.5). Add new numbered file; never edit merged migration.

## Deploy and rollback

`server/deploy/deploy.sh` automates release flow:

- `deploy.sh deploy <tag>`: builds `pontual-api:<tag>`, runs `docker compose up -d`, checks API health with exec command above, checks tunnel with cloudflared command above, records current/previous tags under `/opt/pontual` (default), rolls back on failure.
- `deploy.sh rollback`: reactivates previous tag.
- `deploy.sh status`: runs `docker compose ps`.

Reads `/etc/pontual/api.env`, `/etc/pontual/db.env`, `/etc/pontual/cloudflared.yml`, `/etc/pontual/cloudflared_credentials.json` by default. Check out release tag first, then run `deploy.sh deploy <tag>` with sudo or read access to `/etc/pontual` and Docker socket.

Tag API image with release name and reuse for rollback:

```sh
PONTUAL_TAG=server-v0.1.0 docker compose -f server/deploy/compose.yaml build
PONTUAL_TAG=server-v0.1.0 docker compose -f server/deploy/compose.yaml up -d
```

Host using override must add `-f /etc/pontual/compose.override.yaml` to these commands, or use `deploy.sh` (includes automatically).

`up -d` applies pending migrations and restarts API. To roll back, point `PONTUAL_TAG` at previous image tag and run `up -d` again. Previous image stays on host. Deploy off-peak: restarting API drops live vehicle state (KL6). Migrations forward-only; rollback needing schema change is new migration.

## Empty-database preflight

`deploy.sh deploy` runs read-only preflight before starting/updating stack. Checks whether persistent `pontual-api_pontual-db` volume exists and, when it does, whether `devices` and `learned_routes` contain rows. If volume new, or DB has zero devices and zero learned routes, prints loud warning and refuses to proceed. Rollback excluded.

Guards against starting API on fresh empty PG volume after container migration that did not restore old data. Set `PONTUAL_ALLOW_EMPTY_DB=1` only for genuine first install or intentional reset; never required for normal deploys. Check read-only, never prints env values.

## Optional Compose override

`deploy.sh` automatically includes `/etc/pontual/compose.override.yaml` when it exists. Set `PONTUAL_COMPOSE_OVERRIDE` for different path. Deployment-specific, stays outside repo.

Use when shared `pontual` tunnel also serves another local container on a different Docker network. Attach cloudflared service to that external network and use other container's unique DNS name in tunnel config. Do not publish its port on host.

```yaml
services:
  cloudflared:
    networks:
      - edge
      - egress
      - example
networks:
  example:
    external: true
    name: example_default
```

File must be root-owned mode 0644, not group/world-writable. Attach tunnel container only to dedicated trusted network, because it can reach every container on that network.

## Security controls

- Base images version-pinned (`denoland/deno:2.9.8`, `postgres:18.6`, `amacneil/dbmate:2.36.0`, `cloudflare/cloudflared:2026.11.0`); API deps locked and cached at build, runtime uses `--cached-only`.
- API runs as non-root `deno` on read-only root fs with 16 MiB noexec `/tmp`. All caps dropped, `no-new-privileges`, PIDs/memory/CPU/log size bounded.
- `cloudflared` runs as uid 65532 on read-only root fs, drops all caps, sets `no-new-privileges`, exposes no host port. Uses locally managed config + credentials, not dashboard-managed token.
- Tunnel config mounted at `/etc/cloudflared/config.yml` from `PONTUAL_TUNNEL_CONFIG_FILE` (default `server/secrets/cloudflared.yml`), non-secret. Credentials JSON mounted at `/run/secrets/cloudflared_credentials` from `PONTUAL_TUNNEL_CREDENTIALS_FILE` (default `server/secrets/cloudflared_credentials.json`), never in env or image.
- `migrate` runs as unprivileged numeric user on read-only fs, drops all caps.
- `db` has no published port, bounded resources, no core dumps, `no-new-privileges`.
- No host port published. Metrics and PostgreSQL stay internal.
- TLS required for TCP DB connections. Secrets generated into DB volume, not committed.
- API Deno permissions deny write/run/ffi/sys. Network limited to API bind, metrics listener, DB hosts.
- Secrets only from env files and credentials file. Docker env values visible to root and docker group. Keep docker socket access limited to admin user. Env files root-owned `0600`; tunnel config world-readable `0644`/`0444` or owner uid 65532 owner-read; credentials JSON uid 65532 mode `0400`.
- Logs structured, must never contain coordinates, tokens, session ids or device ids.
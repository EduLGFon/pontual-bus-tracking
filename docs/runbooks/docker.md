# Docker deployment (D101, D102)

The Compose stack runs four services from `server/deploy/compose.yaml`:

- `db`: a pinned `postgres:16.15` container with a named volume. It is never
  published to the host and is only on the internal `data` network.
- `migrate`: a one-shot `amacneil/dbmate:2.36.0` container that applies the
  forward-only migrations in `server/db/migrations/` and exits.
- `api`: the image built from `server/deploy/Dockerfile`, on the internal
  `edge` and `data` networks. It has no published port.
- `cloudflared`: `cloudflare/cloudflared:2026.11.0`, on the internal `edge`
  network and the non-internal `egress` network. It provides the public edge
  through an outbound-only Cloudflare Tunnel.

Networks:

- `edge` (internal): `api` + `cloudflared`.
- `data` (internal): `api` + `db` + `migrate`.
- `egress` (not internal): `cloudflared` only.

Static data is built inside the API image from `data/` and `tools/`. No secret
enters any image.

## Prerequisites

- Docker Engine with Compose v2.
- A locally managed Cloudflare Tunnel named `pontual`. No dashboard-managed
  ingress is required: ingress rules live in the mounted config file. The
  public hostname `api-pontual.spotnik.space` (and optionally
  `api.pontual.spotnik.space`) points at `http://api:8080`. The web app
  origin remains `https://pontual.spotnik.space`.

## Environment

Three secret sources keep credentials out of the API container and out of git:

| File | Used by | Contents |
| --- | --- | --- |
| `server/.env` | `api` | `APP_ENV`, `DATABASE_URL` for the app role, origins, log level |
| `server/.env.db` | `db`, `migrate` | `POSTGRES_PASSWORD`, `PONTUAL_APP_PASSWORD` |
| `server/secrets/cloudflared.yml` | `cloudflared` | tunnel config (non-secret), readable |
| `server/secrets/cloudflared_credentials.json` | `cloudflared` | tunnel credentials, owned by uid 65532 mode 0400 |

Copy both env examples, generate hex passwords, and keep
`PONTUAL_APP_PASSWORD` identical to the password inside the app
`DATABASE_URL`:

```sh
test -f server/.env || cp server/.env.docker.example server/.env
test -f server/.env.db || cp server/.env.db.example server/.env.db
chmod 600 server/.env server/.env.db
openssl rand -hex 32   # migrator password -> server/.env.db POSTGRES_PASSWORD
openssl rand -hex 32   # app password -> PONTUAL_APP_PASSWORD and DATABASE_URL
```

Store the tunnel config (non-secret, world-readable 0644/0444 or owner uid 65532 with owner-read) and the credentials
JSON (secret, owned by uid 65532 mode 0400). The config's `credentials-file`
must be `/run/secrets/cloudflared_credentials`. Never put secrets in compose,
env examples, git, logs or documentation.

```sh
install -d -m 700 server/secrets
cp server/deploy/cloudflared/config.example.yml server/secrets/cloudflared.yml
chmod 644 server/secrets/cloudflared.yml
# Replace the placeholder tunnel UUID with the real one from `cloudflared tunnel list`
# (or the TunnelID field of the credentials JSON).
# place the credentials JSON from `cloudflared tunnel create pontual`, then:
sudo chown 65532:65532 server/secrets/cloudflared_credentials.json
sudo chmod 400 server/secrets/cloudflared_credentials.json
```

Compose preserves the ownership and mode inside the container. The shared tunnel
can keep `api-ephemeron.spotnik.space -> http://host.docker.internal:8091`;
`extra_hosts` provides that path.

Hex avoids URL-encoding problems: Compose builds the migrator URL from
`POSTGRES_PASSWORD`, and `DATABASE_URL` embeds the app password.

`PONTUAL_ENV_FILE`, `PONTUAL_DB_ENV_FILE`, `PONTUAL_TUNNEL_CONFIG_FILE` and `PONTUAL_TUNNEL_CREDENTIALS_FILE`
are read by Compose interpolation from the shell (or from a `.env` file next
to the compose file), not from `server/.env`. Both env files default to paths
next to the compose file. For root-owned files, point the variables at them:

```sh
PONTUAL_ENV_FILE=/etc/pontual/api.env \
PONTUAL_DB_ENV_FILE=/etc/pontual/db.env \
PONTUAL_TUNNEL_CONFIG_FILE=/etc/pontual/cloudflared.yml \
PONTUAL_TUNNEL_CREDENTIALS_FILE=/etc/pontual/cloudflared_credentials.json \
  docker compose -f server/deploy/compose.yaml up -d
```

Compose sets `HOST=0.0.0.0`, `PORT=8080`, `DATA_DIR=/app/build` and a loopback
`METRICS_PORT` inside the API container. Do not override `HOST` to a public
interface: the API is not published.

`DATABASE_URL` must use `db:5432` for the bundled database. The stack is
self-contained: the API has no internet egress and requires the bundled
database.

## Build and run

From the repository root:

```sh
docker compose -f server/deploy/compose.yaml up -d --build
```

`up` starts `db`, waits for its healthcheck, runs `migrate`, waits for it to
exit successfully, then starts `api` and `cloudflared`. Check the result from
inside the containers (there is no host port to curl):

```sh
docker compose -f server/deploy/compose.yaml ps
docker compose -f server/deploy/compose.yaml logs --tail=100 migrate
docker compose -f server/deploy/compose.yaml logs --tail=100 api
docker compose -f server/deploy/compose.yaml exec -T api deno eval --quiet --no-config --allow-net=127.0.0.1:8080 'const r = await fetch("http://127.0.0.1:8080/v1/health"); if (!r.ok) Deno.exit(1);'
docker compose -f server/deploy/compose.yaml exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready
```

`migrate` must show `Exited (0)`. The API image healthcheck calls
`/v1/health` from inside the container.

## Database

The database is reachable only from the compose network. There is no host port
mapping. Open a session through the container:

```sh
docker compose -f server/deploy/compose.yaml exec db \
  psql -U pontual_migrator -d pontual
```

Role model (PLAN.md 6.4):

- `pontual_migrator` owns the schema and is used only by `migrate`.
- `pontual_app` has `SELECT, INSERT, UPDATE, DELETE` on application tables and
  is the only credential in the API `DATABASE_URL`.

The first start creates a self-signed certificate in the database volume and
appends `ssl=on` to `postgresql.conf`. `pg_hba.conf` is switched to `hostssl`,
so cleartext TCP connections are rejected. Clients use `sslmode=require`,
which encrypts without verifying the self-signed certificate. The Unix socket
inside the container remains available to `psql` and the healthcheck.

The named volume is the only persistent state:

```sh
docker volume ls | grep pontual-db
```

Back up with `pg_dump` and the procedure in `docs/runbooks/ops.md`. Never run
`docker compose down -v` unless the data is intentionally being destroyed.

## Migrations

Migrations apply automatically on `up`. dbmate runs with the migrator role,
points at the read-only `server/db/migrations/` mount, and uses
`--no-dump-schema`.

Run the one-shot service again without touching the API:

```sh
docker compose -f server/deploy/compose.yaml run --rm migrate
```

Or run dbmate manually with the migrator URL:

```sh
DATABASE_URL='postgresql://pontual_migrator:...@db:5432/pontual?sslmode=require' \
  dbmate -d server/db/migrations up
```

Migrations remain forward-only and backward compatible for one release
(PLAN.md 17.5). Add a new numbered file; never edit a merged migration.

## Deploy and rollback

`server/deploy/deploy.sh` automates the release flow:

- `deploy.sh deploy <tag>` builds `pontual-api:<tag>`, runs
  `docker compose up -d`, checks API health with the `docker compose exec`
  command above, checks the tunnel with the `cloudflared` command above,
  records current and previous tags under `/opt/pontual` by default, and rolls
  back on failure.
- `deploy.sh rollback` reactivates the previous tag.
- `deploy.sh status` runs `docker compose ps`.

It reads `/etc/pontual/api.env`, `/etc/pontual/db.env`,
`/etc/pontual/cloudflared.yml` and `/etc/pontual/cloudflared_credentials.json` by default. Check out the release tag first, then
run `deploy.sh deploy <tag>` with sudo or with read access to `/etc/pontual`
and the Docker socket.

Tag the API image with the release name and reuse it for rollback:

```sh
PONTUAL_TAG=server-v0.1.0 docker compose -f server/deploy/compose.yaml build
PONTUAL_TAG=server-v0.1.0 docker compose -f server/deploy/compose.yaml up -d
```

`up -d` applies any pending migrations and restarts the API. To roll back,
point `PONTUAL_TAG` at the previous image tag and run `up -d` again. The
previous image stays on the host. Deploy off-peak: restarting the API drops
live vehicle state (KL6). Migrations are forward-only; a rollback that needs a
schema change is a new migration.

## Security controls

- Base images are version-pinned (`denoland/deno:2.9.8`, `postgres:16.15`,
  `amacneil/dbmate:2.36.0`, `cloudflare/cloudflared:2026.11.0`); API
  dependencies are locked and cached at build time, and runtime uses
  `--cached-only`.
- The API runs as the non-root `deno` user on a read-only root filesystem with
  a 16 MiB noexec `/tmp`. All capabilities are dropped,
  `no-new-privileges` is set, and PIDs, memory, CPU and log size are bounded.
- `cloudflared` runs as uid 65532 on a read-only root filesystem, drops all
  capabilities, sets `no-new-privileges`, and exposes no host port. It uses a
  locally managed config plus credentials, not a dashboard-managed token.
- The tunnel config is mounted at `/etc/cloudflared/config.yml` from
  `PONTUAL_TUNNEL_CONFIG_FILE` (default `server/secrets/cloudflared.yml`); it
  is non-secret. The credentials JSON is mounted at
  `/run/secrets/cloudflared_credentials` from
  `PONTUAL_TUNNEL_CREDENTIALS_FILE` (default
  `server/secrets/cloudflared_credentials.json`); it is never in the
  environment or image.
- `migrate` runs as an unprivileged numeric user on a read-only filesystem and
  drops all capabilities.
- `db` has no published port, bounded resources, no core dumps, and a
  `no-new-privileges` policy.
- No host port is published. Metrics and PostgreSQL stay internal.
- TLS is required for TCP database connections. Secrets are generated into the
  database volume, not committed.
- The API Deno permissions deny write, run, ffi and sys. Network access is
  limited to the API bind, the metrics listener and the database hosts.
- Secrets come only from the env files and the credentials file. Docker
  environment values are visible to root and the docker group. Keep docker
  socket access limited to the admin user. Env files are root-owned mode
  `0600`; the tunnel config is world-readable `0644`/`0444` or owner uid 65532 with owner-read; the credentials JSON is
  owned by uid 65532 mode `0400`.
- Logs are structured and must never contain coordinates, tokens, session ids or
  device ids.

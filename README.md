# Pontual

Independent, non-official crowd-sourced bus tracker for Sao Mateus, ES, Brazil.
No affiliation with Viacao Sao Gabriel or the municipality.

- Product name: Pontual
- Android applicationId: `com.spotnik.pontual`
- Design contract: `PLAN.md`
- Agent rules: `AGENTS.md`
- Decisions: `DECISIONS.md`
- Principles: `PRINCIPLES.md`

## Layout

- `app/` - Flutter client (Android + Web/PWA).
- `server/` - Deno/TypeScript API + PostgreSQL migrations.
- `data/` - Static timetable source of truth (`data/lines/*.json`,
  `data/routes/*`).
- `tools/` - Deno tooling and simulator.
- `docs/` - `privacy/`, `security/`, `runbooks/`, `field-tests/`.
- `.github/` - CI and templates.

## Setup

Clone and read `PLAN.md` sections 0, 16, 19 plus `DECISIONS.md` section 6.

- Database: Docker with `postgres:18.6-alpine`, or any local PostgreSQL 18.
- Migrations: dbmate v2.36.0 (release binary, never committed).
- Client env: copy `env/example.json` to `env/dev.json` and set `API_BASE_URL`
  and `STATIC_BASE_URL`. Defaults point at the local server. No secrets in
  client env.
- Server env: copy `server/.env.example` to `server/.env` (gitignored).
  Defaults fit the local run below: database on `127.0.0.1:5433`, metrics on
  `127.0.0.1:9091` (must stay inside the `--allow-net` list in
  `server/deno.json`), static bundle in `../build`. Never commit it.

## Local end-to-end run (verified 2026-10-04)

Terminal 1 - database and migrations:

```sh
docker rm -f pontual-pg 2>/dev/null
docker run -d --name pontual-pg -e POSTGRES_PASSWORD=test \
  -e POSTGRES_DB=pontual_test -p 5433:5432 postgres:18.6-alpine
export DATABASE_URL="postgresql://postgres:test@127.0.0.1:5433/pontual_test?sslmode=disable"
/tmp/dbmate -d ./db/migrations up   # from server/
```

Terminal 2 - static data bundle (from `tools/`):

```sh
deno task data-validate && deno task data-build
```

Terminal 3 - API (from `server/`, needs `server/.env`):

```sh
deno task dev
curl -s http://127.0.0.1:8080/v1/health  # {"ok":true}
```

Terminal 4 - simulated riders (from `tools/`, needs the API up):

```sh
deno task sim -- --base http://127.0.0.1:8080 --line 60 \
  --buses 1 --riders 2 --duration 90 --ping 5 --seed 7
curl -s http://127.0.0.1:8080/v1/live  # e.g. [[60,1]]
```

App in a browser (from `app/`, needs the API up):

```sh
flutter run -d chrome --web-port 5000
```

Port 5000 matters: it is in the default `ALLOWED_ORIGINS`. On Android,
`flutter run` with a connected device works the same way.

Test accounts: none. The app registers an anonymous device token on first
share. Timetables work fully offline from the bundled data.

Warning: never run `deno task test` (from `server/`) against the database
a running server or soak uses. Point `TEST_DATABASE_URL` at a throwaway
database; the suite truncates device rows and toggles the kill switch.

## Server container

The server runs in one Docker Compose stack named `pontual-api` with four
services: `db`, `migrate`, `api` and `cloudflared`. The API is not published
to the host; it is reachable only by `cloudflared` on the internal `edge`
network. PostgreSQL and metrics stay internal too. The stack uses two internal networks (`edge`, `data`) plus a
non-internal `egress` network for the tunnel, a container-only Cloudflare
Tunnel, and no host Caddy or systemd unit. The API runs as a non-root user on
a read-only filesystem, drops all capabilities, and reads secrets from env
files and a locally managed tunnel config plus credentials. The database uses TLS and keeps separate migrator and app roles. Static
data is built inside the image. See `docs/runbooks/docker.md` for the
database, migration, tunnel, deploy and rollback steps.

```sh
# Reuse existing env files; never overwrite real values.
test -f server/.env || cp server/.env.docker.example server/.env
test -f server/.env.db || cp server/.env.db.example server/.env.db
chmod 600 server/.env server/.env.db
# Edit both files: generate hex passwords and keep the app password identical
# in PONTUAL_APP_PASSWORD and DATABASE_URL.
# Store the tunnel config (non-secret, readable) and credentials (secret):
install -d -m 700 server/secrets
cp server/deploy/cloudflared/config.example.yml server/secrets/cloudflared.yml
chmod 644 server/secrets/cloudflared.yml
# Replace the placeholder tunnel UUID with the real one from `cloudflared tunnel list`.
# place the credentials JSON (from cloudflared tunnel create) then:
sudo chown 65532:65532 server/secrets/cloudflared_credentials.json
sudo chmod 400 server/secrets/cloudflared_credentials.json
docker compose -f server/deploy/compose.yaml up -d --build
docker compose -f server/deploy/compose.yaml exec -T api deno eval --quiet --no-config --allow-net=127.0.0.1:8080 'const r = await fetch("http://127.0.0.1:8080/v1/health"); if (!r.ok) Deno.exit(1);'
docker compose -f server/deploy/compose.yaml exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready
```

`docker compose down` keeps the database volume. `down -v` deletes it.

## Run / test / release

- From `app/`: `flutter analyze`, `flutter test`,
  `flutter test --platform chrome` (needs Chrome), `flutter run -d chrome
  --web-port 5000`. The live client contract needs a running server:
  `BUS_API_BASE=http://127.0.0.1:8080 flutter test test/api_test.dart
  --dart-define=BUS_API_LINE=60` (line 7 is the CI seed; the real bundle
  uses official line numbers).
- From `server/`: `deno fmt --check`, `deno lint`, `deno check src/main.ts`,
  `deno task test` (needs `TEST_DATABASE_URL` on a throwaway database plus
  dbmate migrations applied).
- From `tools/`: `deno task data-validate`, `deno task data-build`,
  `deno task sim -- --base <api> --line <id> ...`.
- From the repo root: `deno task check-workflows` lint-checks
  `.github/workflows` and verifies every external action is pinned to a
  resolvable full commit SHA. Pass `--offline` to skip GitHub lookups
  (`bash tools/ci/check_workflows.sh --offline`).
- Release follows PLAN.md 17.3 and 17.5. Deploys are manual by the owner in
  alpha. Release workflows require repo var `API_ORIGIN` (baked in via
  `--dart-define`); `STATIC_ORIGIN` is optional and auto-detected from the
  Pages custom domain. See Domains below for the production values.

### Build speed

Android release builds are CPU-bound (Dart kernel/AOT plus R8), so they take
roughly 1-2 minutes warm on a 4-core machine. Iterate with debug `flutter run`
and reserve release builds for artifacts. Gradle uses a 4 GiB heap, parallel execution and
the local build cache (`app/android/gradle.properties`); do not run
`flutter clean` between builds.

From `app/`:

```sh
# Android device: debug + hot reload, arm64 only
flutter run --debug --target-platform android-arm64 \
  -d <device> --dart-define-from-file=../env/phone.json

# Faster on-device check without hot reload
flutter build apk --debug --target-platform android-arm64 \
  --dart-define-from-file=../env/phone.json

# Android release appbundle, arm64 only, production defines
flutter build appbundle --release --target-platform android-arm64 \
  --dart-define-from-file=../env/phone.json \
  --obfuscate --split-debug-info=build/symbols/android-<version>

# Chrome: debug + hot reload
flutter run -d chrome --web-port 5000 \
  --dart-define-from-file=../env/example.json
```

`permission_handler` stays on 12.x: 13.x requires compileSdk 37, which
Flutter 3.47 and AGP 9.1 do not support (DECISIONS.md). Do not pass `--no-pub`
after `flutter pub get`; pub get writes a debug plugin registrant that includes
`integration_test` and breaks release Java compilation.

## Domains

- App/PWA: `https://pontual.spotnik.space` (GitHub Pages custom domain).
  The Cloudflare record is a DNS-only CNAME `pontual` ->
  `edulgfon.github.io`. Keep it DNS only: with the orange-cloud proxy GitHub
  cannot issue its own certificate for the custom domain.
- API: `https://api-pontual.spotnik.space` (Cloudflare Tunnel `pontual` to
  `http://api:8080` on the internal edge network).
- `api.pontual.spotnik.space` is a second-level subdomain. Cloudflare's free
  Universal SSL covers only the apex and first-level names, and Total TLS does
  not issue for Tunnel hostnames, so that name needs Advanced Certificate
  Manager (USD 10/month). The alpha uses the first-level API hostname; the
  second-level route stays configured for a later ACM decision.

Production web build values:

    API_ORIGIN=https://api-pontual.spotnik.space
    STATIC_ORIGIN=https://pontual.spotnik.space

`deploy-static` requires the `API_ORIGIN` repo variable and derives the
`--base-href` from `STATIC_ORIGIN`. When `STATIC_ORIGIN` is unset, the
workflow reads the Pages custom domain and uses
`https://<custom-domain>` automatically, so the base href follows the live
site. `release-android` uses the same rule. Re-run `deploy-static` after
changing `API_ORIGIN`: editing a variable does not trigger a rebuild.

Temporary easy-test web overrides (repo variables, removed before pilot):

    FIX_ACCURACY_MAX_M=500
    FORCE_PING_BUTTON=true

`deploy-static` bakes these into the PWA. Defaults are 60 and false. Set them
only while the API runs with `APP_ENV=local` and `TEST_EASY_PUBLISH=true`.
The PWA is public, so with easy-publish a visitor can force-publish a
stationary bus. Delete both variables and re-run `deploy-static` before the
pilot.

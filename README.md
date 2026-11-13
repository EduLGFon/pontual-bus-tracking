# Pontual

Independent, non-official crowd-sourced bus tracker for Sao Mateus, ES, Brazil. No affiliation with Viacao Sao Gabriel or the municipality.

- Product: Pontual
- Android applicationId: `com.spotnik.pontual`
- Design contract: `ARCHITECTURE.md`
- Agent rules: `AGENTS.md`
- Decisions: `DECISIONS.md`
- Principles: `PRINCIPLES.md`

## Layout

- `app/` - Flutter client (Android + Web/PWA).
- `server/` - Deno/TypeScript API + PostgreSQL migrations.
- `data/` - Static timetable source of truth (`data/lines/*.json`, `data/routes/*`).
- `tools/` - Deno tooling and simulator.
- `docs/` - `privacy/`, `security/`, `runbooks/`, `field-tests/`.
- `.github/` - CI and templates.

## Setup

Read `ARCHITECTURE.md` sections 0, 16, 19 and `DECISIONS.md` section 6.

- Database: Docker with `postgres:18.6-alpine`, or any local PostgreSQL 18.
- Migrations: dbmate v2.36.0 release binary (never committed).
- Client env: copy `env/example.json` to `env/dev.json`; set `API_BASE_URL` and `STATIC_BASE_URL`. Defaults point at local server. No secrets in client env.
- Server env: copy `server/.env.example` to `server/.env` (gitignored). Defaults fit local run: DB on `127.0.0.1:5433`, metrics on `127.0.0.1:9091` (must stay in `--allow-net` in `server/deno.json`), static bundle in `../build`. Never commit.

## Local end-to-end run (verified 2026-10-04)

Terminal 1 - database and migrations:

```sh
docker rm -f pontual-pg 2>/dev/null
docker run -d --name pontual-pg -e POSTGRES_PASSWORD=test \
  -e POSTGRES_DB=pontual_test -p 5433:5432 postgres:18.6-alpine
export DATABASE_URL="postgresql://postgres:test@127.0.0.1:5433/pontual_test?sslmode=disable"
# from server/
/tmp/dbmate -d ./db/migrations up
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

Terminal 4 - simulated riders (from `tools/`, needs API up):

```sh
deno task sim -- --base http://127.0.0.1:8080 --line 60 \
  --buses 1 --riders 2 --duration 90 --ping 5 --seed 7
curl -s http://127.0.0.1:8080/v1/live  # e.g. [[60,1]]
```

App in browser (from `app/`, needs API up):

```sh
flutter run -d chrome --web-port 5000
```

Port 5000 matters: it is in default `ALLOWED_ORIGINS`. On Android, `flutter run` with a connected device works the same way.

Test accounts: none. The app registers an anonymous device token on first share. Timetables work fully offline from bundled data.

Warning: never run `deno task test` (from `server/`) against the database a running server or soak uses. Point `TEST_DATABASE_URL` at a throwaway database; the suite truncates device rows and toggles the kill switch.

## Server container

Server runs in one Docker Compose stack `pontual-api` with four services: `db`, `migrate`, `api`, `cloudflared`. API is not published to host; reachable only by `cloudflared` on internal `edge` network. PostgreSQL and metrics stay internal. Stack uses two internal networks (`edge`, `data`) plus non-internal `egress` for tunnel, container-only Cloudflare Tunnel, no host Caddy or systemd unit. API runs as non-root on read-only filesystem, drops all capabilities, reads secrets from env files and locally managed tunnel config plus credentials. Database uses TLS with separate migrator and app roles. Static data built inside image. See `docs/runbooks/docker.md`.

```sh
# Reuse existing env files; never overwrite real values.
test -f server/.env || cp server/.env.docker.example server/.env
test -f server/.env.db || cp server/.env.db.example server/.env.db
chmod 600 server/.env server/.env.db
# Edit both: generate hex passwords; keep app password identical in
# PONTUAL_APP_PASSWORD and DATABASE_URL.
# Store tunnel config (non-secret, readable) and credentials (secret):
install -d -m 700 server/secrets
cp server/deploy/cloudflared/config.example.yml server/secrets/cloudflared.yml
chmod 644 server/secrets/cloudflared.yml
# Replace placeholder tunnel UUID with real one from `cloudflared tunnel list`.
# Place credentials JSON (from cloudflared tunnel create), then:
sudo chown 65532:65532 server/secrets/cloudflared_credentials.json
sudo chmod 400 server/secrets/cloudflared_credentials.json
docker compose -f server/deploy/compose.yaml up -d --build
docker compose -f server/deploy/compose.yaml exec -T api deno eval --quiet --no-config --allow-net=127.0.0.1:8080 'const r = await fetch("http://127.0.0.1:8080/v1/health"); if (!r.ok) Deno.exit(1);'
docker compose -f server/deploy/compose.yaml exec -T cloudflared cloudflared tunnel --metrics 127.0.0.1:2000 ready
```

`docker compose down` keeps the DB volume. `down -v` deletes it.

## Run / test / release

- From `app/`: `flutter analyze`, `flutter test`, `flutter test --platform chrome` (needs Chrome), `flutter run -d chrome --web-port 5000`. Live client contract needs running server: `BUS_API_BASE=http://127.0.0.1:8080 flutter test test/api_test.dart --dart-define=BUS_API_LINE=60` (line 7 is CI seed; real bundle uses official line numbers).
- From `server/`: `deno fmt --check`, `deno lint`, `deno check src/main.ts`, `deno task test` (needs `TEST_DATABASE_URL` on throwaway DB plus dbmate migrations applied).
- From `tools/`: `deno task data-validate`, `deno task data-build`, `deno task sim -- --base <api> --line <id> ...`.
- From repo root: `deno task check-workflows` lint-checks `.github/workflows` and verifies every external action pinned to resolvable full commit SHA. Pass `--offline` to skip GitHub lookups (`bash tools/ci/check_workflows.sh --offline`).
- Release follows ARCHITECTURE.md 17.3 and 17.5. Deploys manual by owner in alpha. Release workflows require repo var `API_ORIGIN` (baked via `--dart-define`); `STATIC_ORIGIN` optional and auto-detected from Pages custom domain. See Domains for production values.

### Build speed

Android release builds are CPU-bound (Dart kernel/AOT plus R8), roughly 1-2 minutes warm on 4-core. Iterate with debug `flutter run`; reserve release builds for artifacts. Gradle uses 4 GiB heap, parallel execution, local build cache (`app/android/gradle.properties`); do not run `flutter clean` between builds.

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

`permission_handler` stays on 12.x: 13.x requires compileSdk 37, which Flutter 3.47 and AGP 9.1 do not support (DECISIONS.md). Do not pass `--no-pub` after `flutter pub get`; pub get writes a debug plugin registrant including `integration_test` and breaks release Java compilation.

## Domains

- App/PWA: `https://pontual.spotnik.space` (GitHub Pages custom domain). Cloudflare record is DNS-only CNAME `pontual` -> `edulgfon.github.io`. Keep DNS only: with orange-cloud proxy GitHub cannot issue its own certificate for the custom domain.
- API: `https://api-pontual.spotnik.space` (Cloudflare Tunnel `pontual` to `http://api:8080` on internal edge network).
- `api.pontual.spotnik.space` is a second-level subdomain. Cloudflare free Universal SSL covers only apex and first-level names; Total TLS does not issue for Tunnel hostnames, so that name needs Advanced Certificate Manager (USD 10/month). Alpha uses first-level API hostname; second-level route stays configured for later ACM decision.

Production web build values:

    API_ORIGIN=https://api-pontual.spotnik.space
    STATIC_ORIGIN=https://pontual.spotnik.space

`deploy-static` requires `API_ORIGIN` repo variable and derives `--base-href` from `STATIC_ORIGIN`. When `STATIC_ORIGIN` unset, workflow reads Pages custom domain and uses `https://<custom-domain>` automatically, so base href follows live site. `release-android` uses same rule. Re-run `deploy-static` after changing `API_ORIGIN`: editing a variable does not trigger rebuild.

Temporary easy-test web overrides (repo variables, removed before pilot):

    FIX_ACCURACY_MAX_M=500
    FORCE_PING_BUTTON=true

`deploy-static` bakes these into PWA. Defaults are 60 and false. Set only while API runs with `APP_ENV=local` and `TEST_EASY_PUBLISH=true`. PWA is public, so with easy-publish a visitor can force-publish a stationary bus. Delete both variables and re-run `deploy-static` before pilot.
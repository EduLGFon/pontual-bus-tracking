# Pontual

Independent, non-official crowd-sourced bus tracker for Sao Mateus, ES, Brazil.
No affiliation with Viacao Sao Gabriel or the municipality.

- Product name: Pontual
- Android applicationId: `com.spotnik.pontual`
- Design contract: `PLAN.md`
- Agent rules: `AGENTS.md`
- Decisions: `DECISIONS.md`

## Layout

- `app/` - Flutter client (Android + Web/PWA). Created in T02.
- `server/` - Deno/TypeScript API + PostgreSQL migrations. Created in T06/T07.
- `data/` - Static timetable source of truth (`data/lines/*.json`,
  `data/routes/*`). Built in T14.
- `tools/` - Deno tooling and simulator (T13/T14).
- `docs/` - `privacy/`, `security/`, `runbooks/`, `field-tests/`.
- `.github/` - CI and templates.

## Setup

Clone and read `PLAN.md` sections 0, 16, 19 plus `DECISIONS.md` section 6.

- Flutter version: 3.47.6 (pinned in `.fvmrc`).
- Deno version: 2.9.7 (pinned in `server/deno.json` and CI).
- Database: Docker with `postgres:16-alpine`, or any local PostgreSQL 16.
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
  -e POSTGRES_DB=pontual_test -p 5433:5432 postgres:16-alpine
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
  alpha. Release workflows need repo vars `API_ORIGIN` and `STATIC_ORIGIN`
  (baked in via `--dart-define`); without them prod builds call localhost.

## Domains (TBD)

API and static domains are undecided (DECISIONS.md D22, INFRA-05). Until then:
static on `*.pages.dev`, API on localhost for dev.

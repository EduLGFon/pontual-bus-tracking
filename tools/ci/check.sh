#!/usr/bin/env bash
# Local mirror of .github/workflows/ci.yml plus a dry run of
# deploy-static.yml. No step touches production: the server suite and the
# smoke sim run against a throwaway docker PostgreSQL, and the deploy
# dry run assembles into a temp dir with dummy origins.
#
# Usage: tools/ci/check.sh [--only app|server|tools|deploy] [--skip-web]
#        [--skip-sim] [--with-tiles] [--sim-duration SECS]
# Env:   API_ORIGIN and STATIC_ORIGIN override the dummy deploy origins.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPBASE="${TMPDIR:-/tmp/opencode}"
PG_NAME="pontual-verify-pg"
PG_PORT="5433"
PG_URL="postgresql://postgres:test@127.0.0.1:${PG_PORT}/pontual_test?sslmode=disable"
DBMATE="$TMPBASE/dbmate-verify"
SERVER_PID=""

ONLY="all"
SKIP_WEB=0
SKIP_SIM=0
WITH_TILES=0
SIM_DURATION=60
API_ORIGIN="${API_ORIGIN:-https://api.example.com}"
STATIC_ORIGIN="${STATIC_ORIGIN:-https://owner.example/pontual}"

PASS=0
FAIL=0
FAILED_STEPS=()

usage() {
  sed -n '2,10p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --skip-web) SKIP_WEB=1; shift ;;
    --skip-sim) SKIP_SIM=1; shift ;;
    --with-tiles) WITH_TILES=1; shift ;;
    --sim-duration) SIM_DURATION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1"; usage; exit 2 ;;
  esac
done

run() {
  if "$@"; then
    PASS=$((PASS + 1))
    echo "PASS: $*"
  else
    FAIL=$((FAIL + 1))
    FAILED_STEPS+=("$*")
    echo "FAIL: $*"
  fi
}

want() {
  [ "$ONLY" = "all" ] || [ "$ONLY" = "$1" ]
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required tool: $1"
    exit 2
  }
}

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  if docker ps -q --filter "name=^${PG_NAME}$" 2>/dev/null | grep -q .; then
    docker rm -f "$PG_NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

pg_up() {
  docker rm -f "$PG_NAME" >/dev/null 2>&1 || true
  docker run -d --name "$PG_NAME" -e POSTGRES_PASSWORD=test \
    -e POSTGRES_DB=pontual_test -p "${PG_PORT}:5432" \
    postgres:16-alpine >/dev/null
  for _ in $(seq 1 45); do
    docker exec "$PG_NAME" pg_isready -U postgres >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "postgres never became ready"
  return 1
}

ensure_dbmate() {
  [ -x "$DBMATE" ] && return 0
  mkdir -p "$TMPBASE"
  curl -fsSL -o "$DBMATE" \
    https://github.com/amacneil/dbmate/releases/download/v2.36.0/dbmate-linux-amd64
  chmod +x "$DBMATE"
  "$DBMATE" --version
}

if want app; then
  need flutter
  echo "--- app (ci.yml flutter job) ---"
  run bash -c "cd '$ROOT/app' && flutter analyze"
  run bash -c "cd '$ROOT/app' && dart format --set-exit-if-changed lib test"
  run bash -c "cd '$ROOT/app' && flutter test"
  run bash -c "cd '$ROOT' && bash tools/ci/manifest_audit.sh"
  if [ "$SKIP_WEB" -eq 0 ]; then
    run bash -c "cd '$ROOT/app' && flutter build web --release"
  fi
fi

if want server; then
  need deno
  need docker
  echo "--- server (ci.yml server job) ---"
  run bash -c "cd '$ROOT/server' && deno fmt --check"
  run bash -c "cd '$ROOT/server' && deno lint"
  run bash -c "cd '$ROOT/server' && deno check src/main.ts"
  run pg_up
  run ensure_dbmate
  run bash -c "cd '$ROOT/server' && DATABASE_URL='$PG_URL' '$DBMATE' -d ./db/migrations up"
  run bash -c "cd '$ROOT/server' && TEST_DATABASE_URL='$PG_URL' deno task test"
  if [ "$SKIP_SIM" -eq 0 ]; then
    echo "--- server smoke + simulator ---"
    (cd "$ROOT/server" && APP_ENV=local HOST=127.0.0.1 PORT=8080 \
      DATABASE_URL="$PG_URL" ALLOWED_ORIGINS="http://127.0.0.1:8080" \
      TRUST_CLOUDFLARE=false DATA_DIR=./build LOG_LEVEL=info \
      METRICS_PORT="127.0.0.1:9091" TEST_DATABASE_URL="$PG_URL" \
      LINES_JSON='[{"id":7,"isActive":true}]' \
      deno task start >"$TMPBASE/pontual-verify-server.log" 2>&1 &
      echo $! >"$TMPBASE/pontual-verify-server.pid")
    SERVER_PID="$(cat "$TMPBASE/pontual-verify-server.pid")"
    for _ in $(seq 1 30); do
      curl -sf http://127.0.0.1:8080/v1/health >/dev/null 2>&1 && break
      sleep 1
    done
    if curl -sf http://127.0.0.1:8080/v1/health >/dev/null 2>&1; then
      PASS=$((PASS + 1)); echo "PASS: server health"
    else
      FAIL=$((FAIL + 1)); FAILED_STEPS+=("server health")
      echo "FAIL: server health"; tail -n 30 "$TMPBASE/pontual-verify-server.log"
    fi
    run bash -c "cd '$ROOT/tools' && deno task sim -- --base http://127.0.0.1:8080 --line 7 --buses 1 --riders 2 --duration $SIM_DURATION --ping 5 --seed 1"
    kill "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
  fi
fi

if want tools; then
  need deno
  echo "--- tools/data (ci.yml data job) ---"
  run bash -c "cd '$ROOT/tools' && deno fmt --check"
  run bash -c "cd '$ROOT/tools' && deno lint"
  run bash -c "cd '$ROOT/tools' && deno task data-test"
  run bash -c "cd '$ROOT/tools' && deno task map-test"
  run bash -c "cd '$ROOT/tools' && deno task data-validate"
  run bash -c "cd '$ROOT/tools' && deno task data-build && SIZE=\$(du -sb ../build | cut -f1) && echo \"bundle bytes: \$SIZE (budget 102400)\" && test \"\$SIZE\" -le 102400"
fi

if want deploy; then
  need deno
  need flutter
  echo "--- deploy dry run (deploy-static.yml, dummy origins) ---"
  echo "API=$API_ORIGIN STATIC=$STATIC_ORIGIN"
  BASE_PATH="$(printf '%s' "$STATIC_ORIGIN" | sed -E 's#^https?://[^/]+##')"
  [ -z "$BASE_PATH" ] && BASE_PATH="/"
  case "$BASE_PATH" in */) BASE_HREF="$BASE_PATH" ;; *) BASE_HREF="$BASE_PATH/" ;; esac
  run bash -c "cd '$ROOT/tools' && API_ORIGIN='$API_ORIGIN' deno task data-build"
  run bash -c "cd '$ROOT/app' && flutter build web --release --no-web-resources-cdn --wasm --base-href '$BASE_HREF' --dart-define=API_BASE_URL=$API_ORIGIN --dart-define=STATIC_BASE_URL=$STATIC_ORIGIN/data"
  run bash -c "cd '$ROOT/tools' && deno task map-bbox"
  if [ "$WITH_TILES" -eq 0 ]; then
    echo "SKIP: pmtiles download/extract/verify (pass --with-tiles to run)"
  else
    need curl
    need tar
    mkdir -p "$TMPBASE/pmtiles-bin"
    if ! [ -x "$TMPBASE/pmtiles-bin/pmtiles" ]; then
      curl -fsSL -o "$TMPBASE/go-pmtiles.tar.gz" \
        https://github.com/protomaps/go-pmtiles/releases/download/v1.31.2/go-pmtiles_1.31.2_Linux_x86_64.tar.gz
      tar xzf "$TMPBASE/go-pmtiles.tar.gz" -C "$TMPBASE/pmtiles-bin" pmtiles
    fi
    run bash -c "cd '$ROOT/tools' && export PATH='$TMPBASE/pmtiles-bin:\$PATH' && deno task map-bbox && deno task map-extract ../build/sao_mateus.pmtiles && deno task map-verify ../build/sao_mateus.pmtiles"
  fi
  PAGES="$(mktemp -d "$TMPBASE/pages-dryrun.XXXXXX")"
  # Same globs as the workflow assemble step; nullglob-style failure
  # surfaces here instead of shipping a half-empty site.
  run bash -c "rm -rf '$PAGES' && mkdir -p '$PAGES/data' '$PAGES/maps' && cp -r '$ROOT/app/build/web/.' '$PAGES/' && cp '$ROOT'/build/lines.*.json '$ROOT'/build/stops.*.json '$ROOT'/build/manifest.json '$ROOT'/build/config.json '$PAGES/data/' && cp '$PAGES/index.html' '$PAGES/404.html' && touch '$PAGES/.nojekyll' && ls '$PAGES/data'"
  if [ "$WITH_TILES" -eq 1 ]; then
    run bash -c "cp '$ROOT/build/sao_mateus.pmtiles' '$PAGES/maps/'"
  fi
  rm -rf "$PAGES"
  echo "PASS: dry-run pages dir assembled and removed"
  PASS=$((PASS + 1))
fi

if [ "$ONLY" = "all" ]; then
  if command -v gitleaks >/dev/null 2>&1; then
    echo "--- secrets ---"
    run bash -c "cd '$ROOT' && gitleaks detect --no-banner"
  else
    echo "SKIP: gitleaks not installed (CI runs it)"
  fi
fi

echo "=== $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  printf 'failed:\n  - %s\n' "${FAILED_STEPS[@]}"
  exit 1
fi

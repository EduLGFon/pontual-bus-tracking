#!/usr/bin/env bash
# Compose deployment helper for the Pontual stack.
# Run on the VPS from a checkout of this repository.
# Usage:
#   deploy.sh deploy <tag>
#   deploy.sh rollback
#   deploy.sh status
# Image tags provide rollback. Compose runs migrations before the API and
# cloudflared starts. The API is not published; health checks run inside the
# container. See docs/runbooks/docker.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT/server/deploy/compose.yaml"
COMPOSE_FILES=(-f "$COMPOSE_FILE")
OVERRIDE_FILE="${PONTUAL_COMPOSE_OVERRIDE:-/etc/pontual/compose.override.yaml}"
if [ -f "$OVERRIDE_FILE" ]; then
  COMPOSE_FILES+=(-f "$OVERRIDE_FILE")
fi
STATE_DIR="${PONTUAL_STATE_DIR:-/opt/pontual}"
CURRENT_TAG="$STATE_DIR/current-tag"
PREVIOUS_TAG="$STATE_DIR/previous-tag"
CONFIG_FILE="${PONTUAL_TUNNEL_CONFIG_FILE:-/etc/pontual/cloudflared.yml}"
CREDENTIALS_FILE="${PONTUAL_TUNNEL_CREDENTIALS_FILE:-/etc/pontual/cloudflared_credentials.json}"

export PONTUAL_ENV_FILE="${PONTUAL_ENV_FILE:-/etc/pontual/api.env}"
export PONTUAL_DB_ENV_FILE="${PONTUAL_DB_ENV_FILE:-/etc/pontual/db.env}"
export PONTUAL_TUNNEL_CONFIG_FILE="${PONTUAL_TUNNEL_CONFIG_FILE:-/etc/pontual/cloudflared.yml}"
export PONTUAL_TUNNEL_CREDENTIALS_FILE="${PONTUAL_TUNNEL_CREDENTIALS_FILE:-/etc/pontual/cloudflared_credentials.json}"

compose() { docker compose "${COMPOSE_FILES[@]}" "$@"; }

check_tunnel_files() {
  local cfg="${PONTUAL_TUNNEL_CONFIG_FILE:-/etc/pontual/cloudflared.yml}"
  local cred="${PONTUAL_TUNNEL_CREDENTIALS_FILE:-/etc/pontual/cloudflared_credentials.json}"
  local uid gid mode
  [ -f "$cfg" ] || { echo "tunnel config not found: $cfg"; return 1; }
  read -r uid gid mode <<<"$(stat -c '%u %g %a' "$cfg" 2>/dev/null || true)"
  [ -n "$mode" ] || { echo "cannot read mode for tunnel config: $cfg"; return 1; }
  if [ "$uid" = "65532" ]; then
    [ $((8#$mode & 8#400)) -ne 0 ] || { echo "tunnel config must be readable by uid 65532: $cfg"; echo "  chmod 0400 $cfg  (or 0444/0644)"; return 1; }
  elif [ "$gid" = "65532" ]; then
    [ $((8#$mode & 8#040)) -ne 0 ] || { echo "tunnel config must be readable by uid 65532: $cfg"; echo "  chmod 0440 $cfg  (group 65532)"; return 1; }
  else
    [ $((8#$mode & 8#004)) -ne 0 ] || { echo "tunnel config must be readable by uid 65532: $cfg"; echo "  chmod 0644 $cfg  (or 0444)"; return 1; }
  fi
  [ -f "$cred" ] || { echo "tunnel credentials not found: $cred"; return 1; }
  uid=$(stat -c '%u' "$cred" 2>/dev/null || true)
  mode=$(stat -c '%a' "$cred" 2>/dev/null || true)
  [ -n "$mode" ] || { echo "cannot read mode for tunnel credentials: $cred"; return 1; }
  if [ "$uid" != "65532" ] || [ $((8#$mode & 8#400)) -eq 0 ]; then
    echo "tunnel credentials must be owned by uid 65532 and owner-readable:"
    echo "  sudo chown 65532:65532 $cred && sudo chmod 400 $cred"
    return 1
  fi
}

api_health() {
  compose exec -T api deno eval --quiet --no-config \
    --allow-net=127.0.0.1:8080 \
    'const r = await fetch("http://127.0.0.1:8080/v1/health"); if (!r.ok) Deno.exit(1);'
}

tunnel_health() {
  compose exec -T cloudflared \
    cloudflared tunnel --metrics 127.0.0.1:2000 ready
}

wait_health() {
  local i
  for i in $(seq 1 90); do
    if api_health >/dev/null 2>&1 && tunnel_health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

preflight_db() {
  local volume_name="${COMPOSE_PROJECT_NAME:-pontual-api}_pontual-db"
  local volume_exists=0
  if docker volume inspect "$volume_name" >/dev/null 2>&1; then
    volume_exists=1
  fi

  if [ "$volume_exists" = "0" ]; then
    if [ "${PONTUAL_ALLOW_EMPTY_DB:-0}" = "1" ]; then
      echo "preflight: new database volume; allowed by PONTUAL_ALLOW_EMPTY_DB=1"
      return 0
    fi
    echo "!!! WARNING: persistent database volume '$volume_name' does not exist."
    echo "!!! This looks like a fresh/empty PostgreSQL volume after a container migration."
    echo "!!! Refusing to start to avoid wiping learning and consent data."
    echo "!!! Restore the old database first, or set PONTUAL_ALLOW_EMPTY_DB=1 for a genuine first install."
    return 1
  fi

  compose up -d db >/dev/null 2>&1 || { echo "preflight: cannot start db"; return 1; }
  local i
  for i in $(seq 1 30); do
    if compose exec -T db pg_isready -U pontual_migrator -d pontual >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  local counts
  counts="$(compose exec -T db sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select (select count(*) from devices)::text || '"'"'|'"'"' || (select count(*) from learned_routes)::text;"' 2>/dev/null | tr -d '[:space:]')" || counts=""

  local devices routes
  devices="${counts%%|*}"
  routes="${counts##*|}"

  case "$devices" in ''|*[!0-9]*) devices="";; esac
  case "$routes" in ''|*[!0-9]*) routes="";; esac

  if [ -z "$devices" ] || [ -z "$routes" ]; then
    if [ "${PONTUAL_ALLOW_EMPTY_DB:-0}" = "1" ]; then
      echo "preflight: empty or unqueryable database allowed by PONTUAL_ALLOW_EMPTY_DB=1"
      return 0
    fi
    echo "!!! WARNING: database volume exists but could not confirm devices/learned_routes rows."
    echo "!!! Refusing to start unless PONTUAL_ALLOW_EMPTY_DB=1."
    return 1
  fi

  if [ "$devices" = "0" ] && [ "$routes" = "0" ]; then
    if [ "${PONTUAL_ALLOW_EMPTY_DB:-0}" = "1" ]; then
      echo "preflight: empty database allowed by PONTUAL_ALLOW_EMPTY_DB=1"
      return 0
    fi
    echo "!!! WARNING: database volume exists but has 0 devices and 0 learned_routes."
    echo "!!! This may indicate an empty or wiped database."
    echo "!!! Refusing to start unless PONTUAL_ALLOW_EMPTY_DB=1."
    return 1
  fi

  echo "preflight: database has $devices devices, $routes learned_routes"
  return 0
}

activate() {
  local tag="$1"
  local build="${2:-true}"
  if [ "$build" = "true" ]; then
    preflight_db || return 1
  fi
  check_tunnel_files || return 1
  if [ "$build" = "true" ]; then
    PONTUAL_TAG="$tag" compose build api || { echo "build failed"; return 1; }
  else
    docker image inspect "pontual-api:$tag" >/dev/null 2>&1 || {
      echo "image not found: pontual-api:$tag"
      return 1
    }
  fi
  PONTUAL_TAG="$tag" compose up -d || { echo "compose up failed"; return 1; }
  if wait_health; then
    mkdir -p "$STATE_DIR" || { echo "cannot create $STATE_DIR"; return 1; }
    if [ -f "$CURRENT_TAG" ]; then
      cp "$CURRENT_TAG" "$PREVIOUS_TAG" || { echo "cannot record previous tag"; return 1; }
    fi
    printf '%s\n' "$tag" > "$CURRENT_TAG" || { echo "cannot record current tag"; return 1; }
    echo "deploy $tag live"
    return 0
  fi
  echo "health check failed for $tag"
  return 1
}

case "${1:-}" in
  deploy)
    tag="${2:-}"
    [ -n "$tag" ] || { echo "usage: deploy.sh deploy <tag>"; exit 2; }
    if ! activate "$tag"; then
      if [ -f "$PREVIOUS_TAG" ]; then
        echo "rolling back to $(cat "$PREVIOUS_TAG")"
        activate "$(cat "$PREVIOUS_TAG")" false
      else
        echo "first deploy failed; inspect: docker compose -f $COMPOSE_FILE logs --tail=100 api cloudflared"
      fi
      exit 1
    fi
    ;;
  rollback)
    [ -f "$PREVIOUS_TAG" ] || { echo "no previous tag"; exit 1; }
    tag="$(cat "$PREVIOUS_TAG")"
    activate "$tag" false || { echo "rollback health check failed"; exit 1; }
    ;;
  status)
    compose ps
    if [ -f "$CURRENT_TAG" ]; then
      echo "current tag: $(cat "$CURRENT_TAG")"
    fi
    if [ -f "$CONFIG_FILE" ]; then
      stat -c 'tunnel config: %u:%g %a' "$CONFIG_FILE"
    fi
    if [ -f "$CREDENTIALS_FILE" ]; then
      stat -c 'tunnel credentials: %u:%g %a' "$CREDENTIALS_FILE"
    fi
    if [ -f "$OVERRIDE_FILE" ]; then
      echo "compose override: $OVERRIDE_FILE"
    fi
    ;;
  *)
    echo "usage: deploy.sh deploy <tag> | rollback | status"
    exit 2
    ;;
esac

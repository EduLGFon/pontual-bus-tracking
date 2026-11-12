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

activate() {
  local tag="$1"
  local build="${2:-true}"
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

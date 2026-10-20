#!/usr/bin/env bash
# Static checks for .github/workflows/*.yml: syntax and semantics via
# actionlint, full-SHA pinning for every external action, pinned refs that
# still resolve on GitHub, and one Flutter/Deno version across all workflows.
# This does not run any workflow step; use tools/ci/check.sh for that.
#
# Usage: tools/ci/check_workflows.sh [--offline]
# Env:   ACTIONLINT overrides the actionlint binary (otherwise PATH or a
#        pinned download into $TMPDIR/opencode).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPBASE="${TMPDIR:-/tmp/opencode}"
ACTIONLINT_VERSION="1.7.7"
OFFLINE=0
ACTIONLINT="${ACTIONLINT:-}"

PASS=0
FAIL=0

usage() {
  sed -n '2,10p' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --offline) OFFLINE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1"; usage; exit 2 ;;
  esac
done

ok() {
  PASS=$((PASS + 1))
  echo "PASS: $*"
}

bad() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $*"
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required tool: $1"
    exit 2
  }
}

if [ ! -d "$ROOT/.github/workflows" ]; then
  echo "no .github/workflows directory"
  exit 2
fi

mapfile -t WORKFLOWS < <(
  find "$ROOT/.github/workflows" -maxdepth 1 -type f \
    \( -name '*.yml' -o -name '*.yaml' \) | sort
)
if [ "${#WORKFLOWS[@]}" -eq 0 ]; then
  echo "no workflow files found"
  exit 2
fi

if [ -z "$ACTIONLINT" ]; then
  if command -v actionlint >/dev/null 2>&1; then
    ACTIONLINT="$(command -v actionlint)"
  else
    need curl
    need tar
    mkdir -p "$TMPBASE/actionlint-bin"
    ACTIONLINT="$TMPBASE/actionlint-bin/actionlint"
    if [ ! -x "$ACTIONLINT" ]; then
      curl -fsSL -o "$TMPBASE/actionlint.tar.gz" \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
      tar xzf "$TMPBASE/actionlint.tar.gz" -C "$TMPBASE/actionlint-bin" actionlint
    fi
  fi
fi

echo "--- actionlint ($("$ACTIONLINT" -version | head -n 1)) ---"
if "$ACTIONLINT" "${WORKFLOWS[@]}"; then
  ok "actionlint"
else
  bad "actionlint"
fi

echo "--- pinned action refs ---"
REFS=()
for file in "${WORKFLOWS[@]}"; do
  while IFS= read -r ref; do
    ref="${ref%%#*}"
    ref="$(printf '%s' "$ref" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    case "$ref" in
      ""|./*|docker://*) continue ;;
    esac
    REFS+=("$ref")
    if ! printf '%s' "$ref" | grep -Eq '@[0-9a-f]{40}$'; then
      bad "${file#"$ROOT"/}: '$ref' is not pinned to a full commit SHA"
    fi
  done < <(grep -E '^[[:space:]]*(-[[:space:]]+)?uses:' "$file" | sed -E 's/^.*uses:[[:space:]]*//' || true)
done
if [ "${#REFS[@]}" -gt 0 ]; then
  ok "${#REFS[@]} external action refs scanned for 40-hex SHA pins"
fi

UNIQUE_REFS=()
if [ "${#REFS[@]}" -gt 0 ]; then
  mapfile -t UNIQUE_REFS < <(printf '%s\n' "${REFS[@]}" | awk '!seen[$0]++')
fi

if [ "$OFFLINE" -eq 0 ]; then
  echo "--- pinned refs resolve on GitHub ---"
  for ref in "${UNIQUE_REFS[@]}"; do
    repo="${ref%@*}"
    sha="${ref#*@}"
    printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$' || continue
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
      "https://api.github.com/repos/${repo}/commits/${sha}" || true)"
    case "$code" in
      200) ok "$repo@$sha" ;;
      403|429) echo "SKIP: $repo@$sha (GitHub API rate limited)" ;;
      *) bad "$repo@$sha (HTTP ${code:-no response})" ;;
    esac
  done
else
  echo "SKIP: GitHub ref resolution (--offline)"
fi

echo "--- toolchain versions agree across workflows ---"
for key in flutter-version deno-version; do
  versions="$(grep -hE "^[[:space:]]*${key}:" "${WORKFLOWS[@]}" \
    | sed -E "s/^.*${key}:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[\"']//g; s/[[:space:]]//g" \
    | sort -u)"
  count="$(printf '%s\n' "$versions" | grep -c . || true)"
  if [ "$count" -le 1 ]; then
    ok "$key: ${versions:-not set}"
  else
    bad "$key differs across workflows: $(printf '%s' "$versions" | tr '\n' ' ')"
  fi
done

echo "=== $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

#!/usr/bin/env bash
# Test GitHub Actions workflows.
#
# Default: run static checks (actionlint, SHA pinning, toolchain version
# agreement) via check_workflows.sh AND the local mirror in check.sh, which
# executes ci.yml and the deploy-static.yml dry run (builds, tests, Pages
# assembly). Requires docker and flutter.
#
# --static-only: skip the heavy local mirror and run only the static checks.
#
# Usage: tools/ci/test_workflows.sh [--offline] [--static-only] [check.sh flags...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OFFLINE=()
STATIC_ONLY=0
CHECK_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --offline) OFFLINE=(--offline) ;;
    --static-only) STATIC_ONLY=1 ;;
    *) CHECK_ARGS+=("$arg") ;;
  esac
done

bash "$ROOT/tools/ci/check_workflows.sh" "${OFFLINE[@]}"

if [ "$STATIC_ONLY" -eq 0 ]; then
  bash "$ROOT/tools/ci/check.sh" "${CHECK_ARGS[@]}"
fi
echo "workflow tests: done"
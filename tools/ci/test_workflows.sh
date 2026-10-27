#!/usr/bin/env bash
# Test all GitHub Actions workflows in .github/workflows/.
# Runs actionlint plus the static checks in check_workflows.sh (SHA pinning,
# resolvable refs skipped in offline mode, toolchain version agreement).
# Usage: tools/ci/test_workflows.sh [--offline]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ "$#" -eq 0 ]; then
  exec bash "$ROOT/tools/ci/check_workflows.sh" --offline
else
  exec bash "$ROOT/tools/ci/check_workflows.sh" "$@"
fi
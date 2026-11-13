#!/usr/bin/env bash
# Size report for T03. Reports web first-load size; non-blocking gate.
# Budgets: ARCHITECTURE.md RNF14 (AAB <= 15 MB, web <= 3 MB transferred compressed).
# Full AAB gate with R8/obfuscation lands in T45. See DECISIONS.md T03 entry.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/app"

echo "=== web release build ==="
flutter build web --release --no-web-resources-cdn 2>&1 | tail -n 20 || flutter build web --release 2>&1 | tail -n 20

echo "=== web size report ==="
du -sh build/web || true
echo "main.dart.js size:"
ls -lh build/web/flutter_bootstrap.js build/web/main.dart.js 2>/dev/null || ls -lh build/web/*.js 2>/dev/null || true
echo "total build/web bytes:"
du -sb build/web || true
echo "NOTE: compressed transferred size and AAB gate are enforced in T45, not T03."

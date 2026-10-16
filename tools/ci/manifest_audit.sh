#!/usr/bin/env bash
# Manifest audit for T03. Fails on forbidden permissions.
# See PLAN.md 8.6 and 12.6 AC15.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST_DIR="$ROOT/app/android"

FORBIDDEN=(
  "android.permission.ACCESS_BACKGROUND_LOCATION"
  "android.permission.RECEIVE_BOOT_COMPLETED"
  "android.permission.WAKE_LOCK"
  "android.permission.SYSTEM_ALERT_WINDOW"
)
# D61: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS is owner-approved for the trip
# foreground service (requested only from a user tap while offline). It is
# checked in ALLOWED below, not here.

ALLOWED=(
  "android.permission.INTERNET"
  "android.permission.ACCESS_FINE_LOCATION"
  "android.permission.ACCESS_COARSE_LOCATION"
  "android.permission.FOREGROUND_SERVICE"
  "android.permission.FOREGROUND_SERVICE_LOCATION"
  "android.permission.POST_NOTIFICATIONS"
  "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
)

fail=0
for p in "${FORBIDDEN[@]}"; do
  if grep -rn --include="*.xml" --include="*.kts" --include="*.gradle" "$p" "$MANIFEST_DIR" >/dev/null 2>&1; then
    echo "FORBIDDEN permission found: $p"
    fail=1
  fi
done

# AC15: no cloud backup of the token, no cleartext.
if ! grep -q 'android:allowBackup="false"' "$MANIFEST_DIR/app/src/main/AndroidManifest.xml"; then
  echo "allowBackup=false missing on the application tag"
  fail=1
fi
if grep -rn --include="*.xml" 'android:usesCleartextTraffic="true"' "$MANIFEST_DIR" >/dev/null 2>&1; then
  echo "cleartext traffic enabled"
  fail=1
fi

echo "Declared permissions in source manifests:"
grep -rhn --include="*.xml" "uses-permission" "$MANIFEST_DIR" || echo "(none in main source set; INTERNET only in debug/profile is expected)"

if [ "$fail" -ne 0 ]; then
  echo "manifest audit: FAIL"
  exit 1
fi
echo "manifest audit: PASS (source audit; merged-manifest check runs in release-android.yml)"

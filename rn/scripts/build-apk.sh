#!/usr/bin/env bash
# Build the fastest standalone (offline-installable) release APK for a single
# arm64 device. Bundles JS, targets one ABI, reuses Gradle/cmake caches.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RN_DIR="$REPO_ROOT/rn"
cd "$RN_DIR"

# Toolchain + cache env.
source "$RN_DIR/android-build-env.sh"
export CCACHE_DIR="${CCACHE_DIR:-/home/edubot/.ccache}"
export CMAKE_C_COMPILER_LAUNCHER="ccache"
export CMAKE_CXX_COMPILER_LAUNCHER="ccache"

# Production endpoints (override via env if needed).
export EXPO_PUBLIC_API_BASE_URL="${EXPO_PUBLIC_API_BASE_URL:-https://api-pontual.spotnik.space}"
export EXPO_PUBLIC_STATIC_BASE_URL="${EXPO_PUBLIC_STATIC_BASE_URL:-https://pontual.spotnik.space/data}"
export EXPO_PUBLIC_FIX_ACCURACY_MAX_M="${EXPO_PUBLIC_FIX_ACCURACY_MAX_M:-500}"
export EXPO_PUBLIC_FORCE_PING_BUTTON="${EXPO_PUBLIC_FORCE_PING_BUTTON:-true}"
export EXPO_PUBLIC_APP_VERSION="${EXPO_PUBLIC_APP_VERSION:-0.3.2}"

echo "==> Exporting JS bundle + assets"
npx expo export --platform android

echo "==> Building release APK (arm64-v8a only)"
cd "$RN_DIR/android"
# NOTE: no --offline flag. The first build after any native-dependency
# upgrade must reach the network to populate the Gradle cache
# (expo-modules gradle plugin et al.); later builds reuse the cache
# and stay fast via --build-cache and the Gradle daemon.
./gradlew assembleRelease \
  -PreactNativeArchitectures=arm64-v8a \
  --parallel \
  --build-cache

APK="$RN_DIR/android/app/build/outputs/apk/release/app-release.apk"
if [ -f "$APK" ]; then
  echo "==> BUILD OK"
  echo "APK: $APK"
  ls -lh "$APK"
else
  echo "==> BUILD FAILED: APK not found" >&2
  exit 1
fi
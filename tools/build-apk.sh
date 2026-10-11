#!/bin/sh
# Build a release APK for direct phone testing (sideload).
# Usage: tools/build-apk.sh [env-file]
# Example: tools/build-apk.sh env/dev.json
# The env file must define API_BASE_URL and STATIC_BASE_URL.
# See env/example.json. No secrets belong in client env files.
set -eu

ENV_FILE="${1:-env/dev.json}"

if [ ! -f "$ENV_FILE" ]; then
  echo "error: env file not found: $ENV_FILE" >&2
  echo "Copy env/example.json to $ENV_FILE and set API_BASE_URL and STATIC_BASE_URL." >&2
  exit 1
fi

case "$(cat "$ENV_FILE")" in
  *127.0.0.1*|*localhost*)
    echo "warning: $ENV_FILE points at localhost, which a phone cannot reach." >&2
    echo "warning: use your machine LAN IP instead, e.g. http://192.168.1.10:8080" >&2
    echo "warning: the API must listen on 0.0.0.0 and ALLOWED_ORIGINS must allow it." >&2
    ;;
esac

cd app
flutter build apk --release --split-per-abi \
  --dart-define-from-file="../$ENV_FILE"

echo "APKs in app/build/app/outputs/flutter-apk/ (install the arm64-v8a one on most phones)."

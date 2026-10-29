#!/usr/bin/env bash
# Setup script: install everything needed to build the RN/Expo Android APK.
# Target: Ubuntu/Debian x86_64. Run from the repo root:
#   bash rn/scripts/setup-android-build.sh
# After it finishes, source the generated env file:
#   source rn/android-build-env.sh
set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-$HOME/android-sdk}"
JAVA_HOME_DEFAULT="/usr/lib/jvm/java-17-openjdk-amd64"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# 1. JDK 17
if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q '17\.'; then
  echo "Installing OpenJDK 17..."
  sudo apt-get update
  sudo apt-get install -y openjdk-17-jdk
fi
if [ -d "$JAVA_HOME_DEFAULT" ]; then
  JAVA_HOME="$JAVA_HOME_DEFAULT"
fi
export JAVA_HOME

# 2. Node.js (>=20) via nvm if missing
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | sed 's/v//' | cut -d. -f1)" -lt 20 ]; then
  echo "Installing Node.js via nvm..."
  if [ ! -d "$HOME/.nvm" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install 22
  nvm use 22
fi

# 3. Android command line tools
mkdir -p "$SDK_ROOT/cmdline-tools"
if [ ! -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Downloading Android command line tools..."
  TMP_ZIP="$(mktemp /tmp/cmdline-tools-XXXX.zip)"
  curl -fsSL "$CMDLINE_TOOLS_URL" -o "$TMP_ZIP"
  rm -rf "$SDK_ROOT/cmdline-tools/latest"
  mkdir -p "$SDK_ROOT/cmdline-tools"
  unzip -q "$TMP_ZIP" -d "$SDK_ROOT/cmdline-tools"
  mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest"
  rm -f "$TMP_ZIP"
fi
export ANDROID_HOME="$SDK_ROOT"
export PATH="$SDK_ROOT/cmdline-tools/latest/bin:$SDK_ROOT/platform-tools:$JAVA_HOME/bin:$PATH"

# 4. Accept licenses
yes | sdkmanager --licenses >/dev/null 2>&1 || true

# 5. Install SDK packages
echo "Installing Android SDK packages..."
sdkmanager "platform-tools" \
  "platforms;android-36" \
  "build-tools;36.0.0" \
  "ndk;27.1.12297006" \
  "cmake;3.22.1"

# 6. Write env file
ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/android-build-env.sh"
cat > "$ENV_FILE" <<EOF
export JAVA_HOME="$JAVA_HOME"
export ANDROID_HOME="$SDK_ROOT"
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$JAVA_HOME/bin:\$PATH"
EOF
echo "Wrote $ENV_FILE"

# 7. Install npm deps + prebuild (if rn/ exists)
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -d "$REPO_ROOT/rn" ]; then
  cd "$REPO_ROOT/rn"
  echo "Installing npm dependencies..."
  npm install
  echo "Running expo prebuild (android)..."
  npx expo prebuild --platform android --no-install
fi

echo ""
echo "Setup complete. To build the APK:"
echo "  source $ENV_FILE"
echo "  cd $REPO_ROOT/rn"
echo "  export EXPO_PUBLIC_API_BASE_URL=\"https://api-pontual.spotnik.space\""
echo "  export EXPO_PUBLIC_STATIC_BASE_URL=\"https://pontual.spotnik.space/data\""
echo "  export EXPO_PUBLIC_FIX_ACCURACY_MAX_M=\"500\""
echo "  export EXPO_PUBLIC_FORCE_PING_BUTTON=\"true\""
echo "  export EXPO_PUBLIC_APP_VERSION=\"0.3.2\""
echo "  ./android/gradlew assembleDebug -p android"
EOF
chmod +x rn/scripts/setup-android-build.sh
echo "created"
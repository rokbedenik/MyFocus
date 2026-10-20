#!/usr/bin/env bash
# Builds MyFocus.app into ./dist (release by default, pass "debug" for a debug build)
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP="dist/MyFocus.app"

# Command Line Tools ship an SDK newer than the compiler can read; pick the newest one that works.
# Override with: SDKROOT=/path/to/sdk scripts/build-app.sh
if [[ -z "${SDKROOT:-}" ]]; then
    for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk "$(xcrun --show-sdk-path 2>/dev/null)"; do
        if [[ -d "$sdk" ]]; then export SDKROOT="$sdk"; break; fi
    done
fi
echo "Using SDK: ${SDKROOT}"

swift build -c "$CONFIG" --sdk "$SDKROOT"
BIN="$(swift build -c "$CONFIG" --sdk "$SDKROOT" --show-bin-path)/MyFocus"

echo "Packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MyFocus"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature is enough to run locally
codesign --force --sign - "$APP"
echo "Done: $APP"
echo "Run with: open $APP"

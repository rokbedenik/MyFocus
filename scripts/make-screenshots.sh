#!/usr/bin/env bash
# Renders the README screenshots (docs/screenshots/*.png) from sample data, without launching the app.
#   scripts/make-screenshots.sh [output dir]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-docs/screenshots}"
BUILD="build.noindex"

if [[ -z "${SDKROOT:-}" ]]; then
    for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk "$(xcrun --show-sdk-path 2>/dev/null)"; do
        if [[ -d "$sdk" ]]; then export SDKROOT="$sdk"; break; fi
    done
fi

mkdir -p "$BUILD"
echo "Compiling screenshot tool"
# App sources without the app's entry point; the tool brings its own @main
SOURCES=$(ls Sources/MyFocus/*.swift | grep -v '/main.swift$')
swiftc -O -sdk "$SDKROOT" -target arm64-apple-macosx14.0 \
    -module-cache-path "$BUILD/module-cache" -module-name MyFocusShots \
    $SOURCES scripts/make-screenshots.swift -o "$BUILD/make-screenshots"
"$BUILD/make-screenshots" "$OUT"

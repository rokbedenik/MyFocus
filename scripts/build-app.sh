#!/usr/bin/env bash
# Builds MyFocus.app into ./build.noindex/dist with swiftc (no Xcode; SwiftPM is only used by the editor).
# The ".noindex" suffix keeps Spotlight from listing the build copy next to the installed app.
#   scripts/build-app.sh            release build -> build.noindex/dist/MyFocus.app
#   scripts/build-app.sh debug      debug build
#   scripts/build-app.sh install    release build, then copy to /Applications and launch it
#   scripts/build-app.sh release    release build + zip to release/MyFocus.zip (the prebuilt app in the repo)
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="release"
INSTALL=0
ZIP=0
for arg in "$@"; do
    case "$arg" in
        debug) CONFIG="debug" ;;
        install) INSTALL=1 ;;
        release) ZIP=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done
BUILD="build.noindex"
APP="$BUILD/dist/MyFocus.app"

# Command Line Tools ship an SDK newer than the compiler can read; pick the newest one that works.
# Override with: SDKROOT=/path/to/sdk scripts/build-app.sh
if [[ -z "${SDKROOT:-}" ]]; then
    for sdk in /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk "$(xcrun --show-sdk-path 2>/dev/null)"; do
        if [[ -d "$sdk" ]]; then export SDKROOT="$sdk"; break; fi
    done
fi
echo "Using SDK: ${SDKROOT}"

OPT="-O"
[[ "$CONFIG" == "debug" ]] && OPT="-Onone -g"
mkdir -p "$BUILD"
echo "Compiling ($CONFIG)"
swiftc $OPT -sdk "$SDKROOT" -target arm64-apple-macosx14.0 \
    -module-cache-path "$BUILD/module-cache" -module-name MyFocus \
    Sources/MyFocus/*.swift -o "$BUILD/MyFocus"

echo "Packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/MyFocus" "$APP/Contents/MacOS/MyFocus"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature is enough to run locally
codesign --force --sign - "$APP"
echo "Done: $APP"

if [[ "$ZIP" == "1" ]]; then
    mkdir -p release
    rm -f release/MyFocus.zip
    ditto -c -k --keepParent "$APP" release/MyFocus.zip
    echo "Zipped: release/MyFocus.zip ($(du -h release/MyFocus.zip | cut -f1))"
fi

if [[ "$INSTALL" == "1" ]]; then
    TARGET="/Applications/MyFocus.app"
    echo "Installing to $TARGET"
    # Graceful quit so the app flushes state and turns DND off; fall back to kill
    if pgrep -xq MyFocus; then
        osascript -e 'tell application "MyFocus" to quit' >/dev/null 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -xq MyFocus || break; sleep 0.3; done
        pkill -x MyFocus 2>/dev/null || true
    fi
    rm -rf "$TARGET"
    cp -R "$APP" "$TARGET"
    open "$TARGET"
    echo "Installed and launched. Find it in Spotlight / Launchpad as 'MyFocus'."
elif [[ "$ZIP" == "0" ]]; then
    echo "Run with: open $APP"
fi

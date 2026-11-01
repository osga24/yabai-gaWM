#!/bin/sh
set -eu
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
APP="$BUILD/SpaceSwitch.app"
mkdir -p "$APP/Contents/MacOS"
xcrun clang -O2 -Wall -Wextra -fobjc-arc "$ROOT/src/wm-compat/main.m" -framework Cocoa -o "$BUILD/wm-compat"
xcrun clang -O2 -Wall -Wextra -fobjc-arc -I"$ROOT/src/space-switch" "$ROOT/src/space-switch/main.m" "$ROOT/src/space-switch/CStrafe.c" "$ROOT/src/space-switch/IOHIDPayload.c" -framework Cocoa -framework ApplicationServices -framework IOKit -o "$APP/Contents/MacOS/space-switch"
cp "$ROOT/src/space-switch/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$BUILD"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
MODULES="$AUTOPAUSE_BUILD_DIR/modules"
APP="$AUTOPAUSE_BUILD_DIR/AutoPause.app"
mkdir -p "$MODULES" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -emit-library -static -emit-module -module-name AutoPauseCore Sources/AutoPauseCore/*.swift -emit-module-path "$MODULES/AutoPauseCore.swiftmodule" -o "$MODULES/libAutoPauseCore.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -emit-library -static -emit-module -module-name AutoPausePlatform -I "$MODULES" Sources/AutoPausePlatform/*.swift -emit-module-path "$MODULES/AutoPausePlatform.swiftmodule" -o "$MODULES/libAutoPausePlatform.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -I "$MODULES" -L "$MODULES" -lAutoPausePlatform -lAutoPauseCore Sources/AutoPause/*.swift -o "$APP/Contents/MacOS/AutoPause"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -I "$MODULES" -L "$MODULES" -lAutoPausePlatform -lAutoPauseCore Sources/AutoPauseDiagnostics/main.swift -o "$AUTOPAUSE_BUILD_DIR/AutoPauseDiagnostics"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${AUTOPAUSE_SIGN_IDENTITY:--}" --options runtime --entitlements Resources/AutoPause.entitlements --identifier local.AutoPause "$APP"
codesign --verify --strict --verbose=2 "$APP"
printf 'Built: %s/%s (%s)\n' "$PWD" "$APP" "$AUTOPAUSE_ARCH"

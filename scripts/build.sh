#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
MODULES="$AUTOPAUSE_BUILD_DIR/modules"
APP="$AUTOPAUSE_BUILD_DIR/MicYield.app"
mkdir -p "$MODULES" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -emit-library -static -emit-module -module-name MicYieldCore Sources/MicYieldCore/*.swift -emit-module-path "$MODULES/MicYieldCore.swiftmodule" -o "$MODULES/libMicYieldCore.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -emit-library -static -emit-module -module-name MicYieldPlatform -I "$MODULES" Sources/MicYieldPlatform/*.swift -emit-module-path "$MODULES/MicYieldPlatform.swiftmodule" -o "$MODULES/libMicYieldPlatform.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -parse-as-library -I "$MODULES" -L "$MODULES" -lMicYieldPlatform -lMicYieldCore Sources/MicYield/*.swift -o "$APP/Contents/MacOS/MicYield"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -O -I "$MODULES" -L "$MODULES" -lMicYieldPlatform -lMicYieldCore Sources/MicYieldDiagnostics/main.swift -o "$AUTOPAUSE_BUILD_DIR/MicYieldDiagnostics"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${AUTOPAUSE_SIGN_IDENTITY:--}" --options runtime --entitlements Resources/MicYield.entitlements --identifier local.AutoPause "$APP"
codesign --verify --strict --verbose=2 "$APP"
printf 'Built: %s/%s (%s)\n' "$PWD" "$APP" "$AUTOPAUSE_ARCH"

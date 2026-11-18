#!/bin/bash
# Sourced by build/test scripts. No global SDK or compiler changes.
set -euo pipefail
# Keep the native default paths; explicit targets get isolated build directories.
if [[ -n "${AUTOPAUSE_ARCH:-}" ]]; then
    AUTOPAUSE_BUILD_DIR="build/$AUTOPAUSE_ARCH"
else
    AUTOPAUSE_ARCH="$(uname -m)"
    AUTOPAUSE_BUILD_DIR="build"
fi
case "$AUTOPAUSE_ARCH" in
    arm64|x86_64) ;;
    *) printf 'Unsupported architecture: %s (use arm64 or x86_64)\n' "$AUTOPAUSE_ARCH" >&2; exit 1 ;;
esac
mkdir -p "$AUTOPAUSE_BUILD_DIR/toolchain" "$AUTOPAUSE_BUILD_DIR/module-cache"
AUTOPAUSE_TARGET="$AUTOPAUSE_ARCH-apple-macosx14.2"
AUTOPAUSE_SWIFT_FLAGS=(-swift-version 6 -target "$AUTOPAUSE_TARGET" -module-cache-path "$AUTOPAUSE_BUILD_DIR/module-cache")
AUTOPAUSE_SWIFT_INCLUDE="$(xcrun --find swiftc | sed 's@/bin/swiftc$@/include/swift@')"
# Some upgraded CLT installations leave two identical SwiftBridging module maps.
if [[ -f "$AUTOPAUSE_SWIFT_INCLUDE/module.modulemap" && -f "$AUTOPAUSE_SWIFT_INCLUDE/bridging.modulemap" ]] && /usr/bin/grep -q "^module SwiftBridging" "$AUTOPAUSE_SWIFT_INCLUDE/module.modulemap" && /usr/bin/grep -q "^module SwiftBridging" "$AUTOPAUSE_SWIFT_INCLUDE/bridging.modulemap"; then
    : > "$AUTOPAUSE_BUILD_DIR/toolchain/empty.modulemap"
    /usr/bin/python3 - "$AUTOPAUSE_SWIFT_INCLUDE/module.modulemap" "$PWD/$AUTOPAUSE_BUILD_DIR/toolchain/empty.modulemap" "$AUTOPAUSE_BUILD_DIR/toolchain/overlay.json" <<'OVERLAY'
import json,sys
from pathlib import Path
Path(sys.argv[3]).write_text(json.dumps({'version':0,'roots':[{'type':'file','name':sys.argv[1],'external-contents':sys.argv[2]}]}))
OVERLAY
    AUTOPAUSE_SWIFT_FLAGS+=(-vfsoverlay "$AUTOPAUSE_BUILD_DIR/toolchain/overlay.json")
fi

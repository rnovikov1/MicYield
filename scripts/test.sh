#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
if [[ "$AUTOPAUSE_ARCH" != "$(uname -m)" ]]; then
    printf 'Tests must run on the host architecture (%s).\n' "$(uname -m)" >&2
    exit 1
fi
TESTS="$AUTOPAUSE_BUILD_DIR/tests"
mkdir -p "$TESTS"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -emit-library -static -emit-module -module-name AutoPauseCore Sources/AutoPauseCore/*.swift -emit-module-path "$TESTS/AutoPauseCore.swiftmodule" -o "$TESTS/libAutoPauseCore.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -emit-library -static -emit-module -module-name AutoPausePlatform -I "$TESTS" Sources/AutoPausePlatform/*.swift -emit-module-path "$TESTS/AutoPausePlatform.swiftmodule" -o "$TESTS/libAutoPausePlatform.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -I "$TESTS" -L "$TESTS" -lAutoPausePlatform -lAutoPauseCore Tests/AutoPauseCoreTests/*.swift -o "$TESTS/AutoPauseTests"
"$TESTS/AutoPauseTests"

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
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -emit-library -static -emit-module -module-name MicYieldCore Sources/MicYieldCore/*.swift -emit-module-path "$TESTS/MicYieldCore.swiftmodule" -o "$TESTS/libMicYieldCore.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -emit-library -static -emit-module -module-name MicYieldPlatform -I "$TESTS" Sources/MicYieldPlatform/*.swift -emit-module-path "$TESTS/MicYieldPlatform.swiftmodule" -o "$TESTS/libMicYieldPlatform.a"
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" -parse-as-library -I "$TESTS" -L "$TESTS" -lMicYieldPlatform -lMicYieldCore Tests/MicYieldCoreTests/*.swift -o "$TESTS/MicYieldTests"
"$TESTS/MicYieldTests"

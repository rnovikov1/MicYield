#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/releases
STAGING="$(mktemp -d "$PWD/build/releases/.package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

verify_app() {
    local app="$1" expected="$2" actual
    actual="$(/usr/bin/lipo -archs "$app/Contents/MacOS/MicYield")"
    if [[ "$actual" != "$expected" ]]; then
        printf 'Wrong architecture for %s: expected %s, found %s\n' "$app" "$expected" "$actual" >&2
        exit 1
    fi
    /usr/bin/codesign --verify --strict --verbose=2 "$app"
}

for arch in arm64 x86_64; do
    case "$arch" in
        arm64) name="MicYield-Apple-Silicon.zip" ;;
        x86_64) name="MicYield-Intel.zip" ;;
    esac
    AUTOPAUSE_ARCH="$arch" bash scripts/build.sh
    app="$PWD/build/$arch/MicYield.app"
    verify_app "$app" "$arch"
    [[ "$(/usr/bin/lipo -archs "build/$arch/MicYieldDiagnostics")" == "$arch" ]]
    archive="$STAGING/$name"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
    /usr/bin/unzip -tq "$archive"
    /usr/bin/ditto -x -k "$archive" "$STAGING/$arch"
    verify_app "$STAGING/$arch/MicYield.app" "$arch"
    mv -f "$archive" "build/releases/$name"
    printf 'Release: %s/build/releases/%s (%s)\n' "$PWD" "$name" "$arch"
done

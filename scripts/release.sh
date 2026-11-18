#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
RELEASE_DIR="$PWD/build/releases/v$VERSION"
mkdir -p "$RELEASE_DIR"
STAGING="$(mktemp -d "$RELEASE_DIR/.package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

verify_app() {
    local app="$1" expected="$2" actual
    actual="$(/usr/bin/lipo -archs "$app/Contents/MacOS/MicYield")"
    if [[ "$expected" == universal ]]; then
        /usr/bin/lipo "$app/Contents/MacOS/MicYield" -verify_arch arm64 x86_64
        [[ "$(wc -w <<< "$actual" | tr -d ' ')" == 2 ]]
    elif [[ "$actual" != "$expected" ]]; then
        printf 'Wrong architecture for %s: expected %s, found %s\n' "$app" "$expected" "$actual" >&2
        exit 1
    fi
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$VERSION" ]]
    cmp Resources/MicYield.icns "$app/Contents/Resources/MicYield.icns"
    cmp Resources/BuyMeACoffee.png "$app/Contents/Resources/BuyMeACoffee.png"
    cmp Resources/BuyMeACoffee-NOTICE.txt "$app/Contents/Resources/BuyMeACoffee-NOTICE.txt"
    /usr/bin/codesign --verify --strict --verbose=2 "$app"
}

for arch in arm64 x86_64; do
    AUTOPAUSE_ARCH="$arch" bash scripts/build.sh
    [[ "$(/usr/bin/lipo -archs "build/$arch/MicYieldDiagnostics")" == "$arch" ]]
    verify_app "$PWD/build/$arch/MicYield.app" "$arch"
done

UNIVERSAL="$STAGING/MicYield.app"
/usr/bin/ditto build/x86_64/MicYield.app "$UNIVERSAL"
/usr/bin/lipo -create build/arm64/MicYield.app/Contents/MacOS/MicYield build/x86_64/MicYield.app/Contents/MacOS/MicYield -output "$UNIVERSAL/Contents/MacOS/MicYield"
/usr/bin/codesign --force --sign "${AUTOPAUSE_SIGN_IDENTITY:--}" --options runtime --entitlements Resources/MicYield.entitlements --identifier local.AutoPause "$UNIVERSAL"
verify_app "$UNIVERSAL" universal
bash scripts/package-dmg.sh "$UNIVERSAL" "$RELEASE_DIR/MicYield.dmg"

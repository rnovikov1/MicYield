#!/bin/bash
# Native, repeatable DMG packaging; no Finder/AppleScript automation.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
APP="${1:?Usage: scripts/package-dmg.sh /absolute/path/MicYield.app [output.dmg]}"
OUTPUT="${2:-$ROOT/build/releases/v$VERSION/MicYield.dmg}"
[[ "$APP" == /* && "$OUTPUT" == /* && "$(basename "$APP")" == MicYield.app ]]
TOOLS="$ROOT/build/dmg-tools"
PYTHON="$TOOLS/bin/python"
if [[ ! -x "$PYTHON" ]]; then /usr/bin/python3 -m venv "$TOOLS"; fi
PIP_DISABLE_PIP_VERSION_CHECK=1 "$PYTHON" -m pip install --quiet --index-url https://pypi.org/simple --only-binary=:all: --require-hashes -r Resources/DMG/requirements.txt
mkdir -p "$(dirname "$OUTPUT")"
STAGING="$(mktemp -d "$(dirname "$OUTPUT")/.dmg.XXXXXX")"
MOUNT="$STAGING/mount"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" == 1 ]]; then
        if ! /usr/bin/hdiutil detach "$MOUNT"; then
            printf 'Could not detach %s; preserving staging directory.\n' "$MOUNT" >&2
            return
        fi
    fi
    rm -rf "$STAGING"
}
trap cleanup EXIT

verify_app() {
    local app="$1" actual
    /usr/bin/lipo "$app/Contents/MacOS/MicYield" -verify_arch arm64 x86_64
    actual="$(/usr/bin/lipo -archs "$app/Contents/MacOS/MicYield")"
    [[ "$(wc -w <<< "$actual" | tr -d ' ')" == 2 ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" == local.AutoPause ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$VERSION" ]]
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" == "$BUILD" ]]
    cmp Resources/Info.plist "$app/Contents/Info.plist"
    for resource in MicYield.icns BuyMeACoffee.png BuyMeACoffee-NOTICE.txt; do
        cmp "Resources/$resource" "$app/Contents/Resources/$resource"
    done
    /usr/bin/codesign --verify --strict --verbose=2 "$app"
}
verify_app "$APP"
mkdir -p "$STAGING/artwork"
# Match the native compiler target and the project-local CLT module-map workaround.
AUTOPAUSE_ARCH="$(uname -m)"
source scripts/toolchain.sh
swiftc "${AUTOPAUSE_SWIFT_FLAGS[@]}" Resources/DMG/Background.swift -o "$TOOLS/render-background"
"$TOOLS/render-background" "$STAGING/artwork"
"$PYTHON" -m dmgbuild -s Resources/DMG/settings.py -D "app=$APP" -D "root=$ROOT" -D "background=$STAGING/artwork/background.png" MicYield "$STAGING/MicYield.dmg"
/usr/bin/hdiutil verify "$STAGING/MicYield.dmg"
mkdir "$MOUNT"
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" -plist "$STAGING/MicYield.dmg" > "$STAGING/mount.plist"
MOUNTED=1
/usr/sbin/diskutil info -plist "$MOUNT" > "$STAGING/volume.plist"
verify_app "$MOUNT/MicYield.app"
[[ -L "$MOUNT/Applications" && "$(readlink "$MOUNT/Applications")" == /Applications ]]
cmp Resources/MicYield.icns "$MOUNT/.VolumeIcon.icns"
"$PYTHON" - "$MOUNT" "$STAGING/mount.plist" "$STAGING/volume.plist" <<'PY'
import plistlib, subprocess, sys
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias
root = Path(sys.argv[1])
with open(sys.argv[2], 'rb') as f:
    mount = plistlib.load(f)
assert any(e.get('mount-point') == str(root) for e in mount['system-entities'])
with open(sys.argv[3], 'rb') as f:
    volume = plistlib.load(f)
assert volume['VolumeName'] == 'MicYield'
assert volume['WritableVolume'] is False
assert {p.name for p in root.iterdir() if not p.name.startswith('.')} == {'MicYield.app', 'Applications'}
assert root.joinpath('.background.tiff').stat().st_size > 0
finder_info = bytes.fromhex(subprocess.check_output(
    ['/usr/bin/xattr', '-px', 'com.apple.FinderInfo', str(root)], text=True))
assert int.from_bytes(finder_info[8:10], 'big') & 0x0400, 'Missing custom volume icon flag'
with DSStore.open(str(root / '.DS_Store'), 'r') as store:
    assert store['.']['icvl'] == (b'type', b'icnv')
    assert store['MicYield.app']['Iloc'] == (165, 172)
    assert store['Applications']['Iloc'] == (475, 172)
    view = store['.']['icvp']
    assert view['iconSize'] == 96 and view['textSize'] == 13
    assert view['arrangeBy'] == 'none' and view['backgroundType'] == 2
    alias = Alias.from_bytes(view['backgroundImageAlias'])
    assert alias.target.filename == '.background.tiff'
    window = store['.']['bwsp']
    assert window['WindowBounds'] == '{{180, 180}, {640, 360}}'
    assert not any(window[k] for k in ('ShowToolbar', 'ShowSidebar', 'ShowStatusBar', 'ShowTabView', 'ShowPathbar'))
print('Verified Finder layout: 640x360, 96pt icons at (165,172)/(475,172), cream/coral Retina background, custom volume icon.')
print('Verified mounted app: Universal arm64+x86_64, version/build, local.AutoPause identity, signature and bundled resources.')
PY
/usr/bin/hdiutil detach "$MOUNT"
MOUNTED=0
mv -f "$STAGING/MicYield.dmg" "$OUTPUT"
"$PYTHON" - "$OUTPUT" <<'PY'
import hashlib, sys
from pathlib import Path
p = Path(sys.argv[1])
print(f'Release: {p}\nSize: {p.stat().st_size} bytes\nSHA256: {hashlib.sha256(p.read_bytes()).hexdigest()}')
PY

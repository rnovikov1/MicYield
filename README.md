# MicYield

A local menu bar app for macOS 14.2+, built with Swift 6 and SwiftUI. All app text is in English.

MicYield mutes system audio while an app uses your microphone, then restores the sound level it changed. Music and videos keep playing silently. It uses Core Audio metadata and output controls, needs no browser extension, and never records audio.

## Download for Mac

- [Apple Silicon (M1 or newer)](https://github.com/rrabochiy/MicYield/releases/download/v0.3.1/MicYield-Apple-Silicon.zip)
- [Intel](https://github.com/rrabochiy/MicYield/releases/download/v0.3.1/MicYield-Intel.zip)
- [All releases](https://github.com/rrabochiy/MicYield/releases)

Requires macOS 14.2 or later. Unzip the download, move MicYield to Applications, and launch it from your menu bar.

## Using the menu

- **Automatic audio muting** silences the default media and system-sound outputs while the microphone is in use. Turning it off restores output controls changed by MicYield immediately.
- **Open at login** starts MicYield when you sign in to your Mac.
- **Quit MicYield** closes the app and restores system sound settings changed by MicYield.

Audio returns after the microphone has been idle for 0.8 seconds. Calls and other apps holding an audio input open trigger the same behavior as dictation. Playback keeps advancing while muted; MicYield does not control music players.

## Permissions and privacy

MicYield does not use Apple Events or macOS Automation. It needs no permission to control other apps, and has no Automation permission buttons or entitlement. It also needs no Microphone, Screen Recording, or Accessibility access: Core Audio reports input activity without providing audio samples.

There are no network requests, servers, telemetry, or subscriptions in the app.

## Build and run

Install Apple's Command Line Tools (`xcode-select --install`) or Xcode. No Homebrew, external packages, subscription, or paid developer account is required.

```sh
cd MicYield
bash scripts/test.sh
bash scripts/build.sh
open build/MicYield.app
```

The app bundle is `build/MicYield.app`, built for the current Mac's architecture. For everyday use, keep one installed copy at `/Applications/MicYield.app` and launch it from there.

The app is ad-hoc signed by default. Set `AUTOPAUSE_SIGN_IDENTITY` to use your own signing certificate. After updating an installed copy, verify that its Open at Login entry points to `/Applications/MicYield.app`.

MicYield retains the legacy `local.AutoPause` bundle identifier and `systemAudioLeases` recovery records. The single muting switch uses `automaticAudioMutingEnabled`; until explicitly changed, it inherits the previous combined `autoPauseEnabled && systemAudioDuckingEnabled` value, with each missing old setting defaulting to true. Existing legacy settings are left intact, so an upgrade does not silently enable previously disabled muting or discard recoverable output levels. The existing `AUTOPAUSE_*` build environment variables remain supported.

`Package.swift` supports Xcode and a healthy SwiftPM installation. The build scripts use `swiftc` directly to avoid the incompatible PackageDescription interface found in the current Command Line Tools. A local VFS overlay handles duplicated SwiftBridging module maps without modifying the installed SDK.

## Apple Silicon and Intel downloads

Build both architectures and package separate app downloads with the installed Apple SDK:

```sh
bash scripts/release.sh
```

Artifacts: `build/releases/MicYield-Apple-Silicon.zip` and `build/releases/MicYield-Intel.zip`. Each contains `MicYield.app`; extract it and move it to Applications. Signing uses `AUTOPAUSE_SIGN_IDENTITY` when supplied, otherwise ad-hoc signing.

For a single architecture, run `AUTOPAUSE_ARCH=arm64 bash scripts/build.sh` or `AUTOPAUSE_ARCH=x86_64 bash scripts/build.sh`. Explicit targets use `build/arm64` and `build/x86_64`; plain `bash scripts/build.sh` retains the host build at `build/MicYield.app`. Cross-compilation verifies binary architecture and signature; it does not replace testing on the target hardware.

## System sound restoration

MicYield prefers the output device's master mute, leaving volume unchanged. If unavailable, it temporarily sets the master volume or all output channels to zero. It manages the default media output and the default system-sound output.

Only controls changed by MicYield are restored. Observed manual changes take precedence until the next microphone session. Switching outputs restores the old device and silences the new one. Disabling muting, quitting, locking, or sleeping restores sound immediately.

Original control values are stored locally before changing them. After a forced termination, recovery can occur on the next launch; immediate recovery after `kill -9` is not guaranteed. A disconnected output's recovery record is retained until it returns. Devices without software mute or volume controls, such as some HDMI outputs, show an explanatory message. Custom per-app routing to other devices is not changed.

## Diagnostics

```sh
build/MicYieldDiagnostics
build/MicYieldDiagnostics --watch 30
build/MicYieldDiagnostics --outputs
# Briefly mute and immediately restore the real audio output:
build/MicYieldDiagnostics --exercise-duck
```

The diagnostic tool reads input metadata and output controls. It does not query or control music players, request Automation access, or record sound. The explicit `--exercise-duck` option briefly changes system sound and restores it afterward.

## Verification and limits

The suite contains 15 tests for output muting and restoration, manual overrides, output changes, saved recovery, cancellation, and independent sleep/lock holds. Native mute/restore was previously verified on this Mac; Apple Silicon builds still need execution on Apple Silicon hardware.

Input activity is polled every 200 ms. Very short input sessions can be missed; an app that holds its input open continuously keeps automatic muting active. Unknown input activity never counts as the end of microphone use. Muting and restoration run on a dedicated queue.

## License

MIT. See [LICENSE](LICENSE). Source code is available to read, build, modify, and redistribute.

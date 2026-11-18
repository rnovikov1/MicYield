# MicYield

A local menu bar app for macOS 14.2+, built with Swift 6 and SwiftUI. All app text is in English.

When an app uses your microphone, MicYield pauses Apple Music and Spotify. It resumes only music that it paused. It can also mute system audio so YouTube and other apps are silent during dictation, without a browser extension.

## Download for Mac

- [Apple Silicon (M1 or newer)](https://github.com/rrabochiy/MicYield/releases/download/v0.3.0/MicYield-Apple-Silicon.zip)
- [Intel](https://github.com/rrabochiy/MicYield/releases/download/v0.3.0/MicYield-Intel.zip)
- [All releases](https://github.com/rrabochiy/MicYield/releases)

Requires macOS 14.2 or later. Unzip the download, move MicYield to Applications, and launch it from your menu bar.

## Using the menu

- **Automatic audio control** is the master switch. Music pauses when the microphone is in use, then resumes only if MicYield paused it. Turning this off also stops automatic muting.
- **Mute all other audio** silences YouTube and other apps while the microphone is in use. Videos keep playing. Your previous sound level returns afterward.
- **Open at login** starts MicYield when you sign in to your Mac.
- **Open Automation Settings…** lets you allow MicYield to control Apple Music and Spotify.
- **Quit MicYield** closes the app, stops automatic audio control, and restores system sound settings changed by MicYield.

Audio returns after the microphone has been idle for 0.8 seconds. Calls and other apps using an open audio input trigger the same behavior as dictation. MicYield never records audio.

## Build and run

Install Apple's Command Line Tools (`xcode-select --install`) or Xcode. No Homebrew, external packages, subscription, or paid developer account is required.

```sh
cd MicYield
bash scripts/test.sh
bash scripts/build.sh
open build/MicYield.app
```

The app bundle is `build/MicYield.app`. It is built for the current Mac's architecture. For everyday use, keep one installed copy at `/Applications/MicYield.app` and launch it from there.

The app is ad-hoc signed by default. You can set `AUTOPAUSE_SIGN_IDENTITY` to use your own signing certificate. Rebuilding can cause macOS to request Automation access again. After updating an installed copy, verify that its Open at Login entry still points to `/Applications/MicYield.app`.

MicYield keeps the legacy `local.AutoPause` bundle identifier, saved settings, and audio recovery records so upgrades preserve preferences and can restore previously muted outputs. The existing `AUTOPAUSE_*` build environment variables remain supported.

`Package.swift` supports Xcode and a healthy SwiftPM installation. The build scripts use `swiftc` directly to avoid the incompatible PackageDescription interface found in the current Command Line Tools. A local VFS overlay handles duplicated SwiftBridging module maps without modifying the installed SDK.

## Apple Silicon and Intel downloads

Build both architectures and package separate app downloads with the installed Apple SDK:

```sh
bash scripts/release.sh
```

Artifacts: `build/releases/MicYield-Apple-Silicon.zip` and `build/releases/MicYield-Intel.zip`. Each contains `MicYield.app`; extract it and move it to Applications. Signing uses `AUTOPAUSE_SIGN_IDENTITY` when supplied, otherwise ad-hoc signing.

For a single architecture, run `AUTOPAUSE_ARCH=arm64 bash scripts/build.sh` or `AUTOPAUSE_ARCH=x86_64 bash scripts/build.sh`. Explicit targets use `build/arm64` and `build/x86_64`; plain `bash scripts/build.sh` retains the host build at `build/MicYield.app`. Cross-compilation verifies binary architecture and signature; it does not replace testing on the target hardware.

## Permissions

Open the menu and click **Allow Control** for each running music app. If access was denied, use **Open Automation Settings…** to enable it in System Settings. Closed players are never launched in the background; **Open Apple Music** or **Open Spotify** launches one only when clicked.

System muting needs no Chrome extension or permission to control Chrome. MicYield does not need Microphone, Screen Recording, or Accessibility access: Core Audio reports input activity without providing audio samples.

## Playback ownership

A successful pause records the player process, track, and playback position. MicYield resumes only the same paused track in the same process, within a two-second position tolerance. Playing, stopping, seeking, changing tracks, or restarting the player cancels automatic resuming. A redundant Pause action while already paused cannot be distinguished from no action.

Disabling audio control, quitting, locking, or sleeping leaves music paused and drops playback ownership. Input errors are never treated as the end of recording.

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

The diagnostic tool reads input metadata and output controls. It never records sound. It is a separate executable, so its Automation permission state may differ from the app's.

## Verification and limits

The suite contains 31 tests for playback ownership, muting, manual overrides, output changes, recovery, and cancellation. Native mute/restore and live YouTube playback during Codex dictation were verified on this Mac. Spotify is not installed locally, so its live playback remains unverified. Its command terminology is read from its installed scripting dictionary.

Input activity is polled every 200 ms. Very short input sessions can be missed; an app that holds its input open continuously keeps automatic audio control active. Apple Events use a two-second timeout. Muting runs on its own queue so player commands do not delay sound restoration.

There are no network requests, servers, telemetry, or subscriptions in the app. See [verification notes](docs/verification.md) for the recorded checks and remaining manual scenarios.

## License

MIT. See [LICENSE](LICENSE). Source code is available to read, build, modify, and redistribute.

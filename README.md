# MicYield

**Automatically Mute Mac Audio During Dictation**

[Download for Mac](https://github.com/rrabochiy/MicYield/releases/download/v0.3.4/MicYield-Universal.zip) · [Website](https://micyield.xyz/) · [Support MicYield](https://buymeacoffee.com/sosun)

Your Mac goes quiet while you dictate. Your sound comes back when you’re done.

Made for people who dictate tasks in Codex, ChatGPT, or their usual app.

A native menu bar app for macOS 14.2+, built with Swift 6 and SwiftUI.

- Mutes audio from music players, videos, browsers, and other apps on your Mac’s default outputs.
- Restores only its own sound changes; your manual adjustments take priority.
- Runs locally without recording audio or sending telemetry.
- Free and open source under MIT, with no account, subscription, or browser extension.

Music and videos keep playing silently while muted. MicYield controls sound output, rather than pausing playback.

## Download for Mac

- [Download for Mac — Universal, Apple Silicon and Intel](https://github.com/rrabochiy/MicYield/releases/download/v0.3.4/MicYield-Universal.zip)
- [Apple Silicon (M1 or newer)](https://github.com/rrabochiy/MicYield/releases/download/v0.3.4/MicYield-Apple-Silicon.zip)
- [Intel](https://github.com/rrabochiy/MicYield/releases/download/v0.3.4/MicYield-Intel.zip)
- [All releases](https://github.com/rrabochiy/MicYield/releases)

Requires macOS 14.2 or later. The Universal download runs on both Apple Silicon and Intel Macs.

1. Open the downloaded ZIP.
2. Move **MicYield.app** to **Applications**.
3. Launch MicYield from Applications and look for its icon in the menu bar. It does not open a regular app window.
4. Turn on **Mute audio on mic use**.
5. Play some audio and start a short dictation. The sound mutes while the microphone is active and returns after you finish.

Optionally enable **Open at login** to have MicYield ready when you sign in. During calls, turn off **Mute audio on mic use** so you can hear the other participants.

## Using the menu

- **Mute audio on mic use** silences the default media and system-sound outputs while the microphone is in use. Turning it off restores output controls changed by MicYield immediately.
- **Open at login** starts MicYield when you sign in to your Mac.
- **MicYield website** opens [micyield.xyz](https://micyield.xyz/) in your browser.
- **Buy me a coffee** opens the optional [support page](https://buymeacoffee.com/sosun). No payment widget or background network request runs in the app.
- **Quit & restore sound** closes the app and restores system sound settings changed by MicYield.

Audio returns after the microphone has been idle for 0.8 seconds. Calls and other apps holding an audio input open trigger the same behavior as dictation. Playback keeps advancing while muted; MicYield does not control music players.

## Permissions and privacy

MicYield checks microphone activity through Core Audio metadata without receiving audio samples. It does not record or transcribe your voice and does not need Microphone, Screen Recording, or Accessibility access.

There are no network requests, servers, telemetry, or subscriptions in the app.

## Build and run

Install Apple's Command Line Tools (`xcode-select --install`) or Xcode. No Homebrew, external packages, subscription, or paid developer account is required.

```sh
git clone https://github.com/rrabochiy/MicYield.git
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

Artifacts are written to `build/releases/v<version>/`: `MicYield-Universal.zip`, `MicYield-Apple-Silicon.zip`, and `MicYield-Intel.zip`. The Universal app contains both native executable architectures. Each contains `MicYield.app`; extract it and move it to Applications. Signing uses `AUTOPAUSE_SIGN_IDENTITY` when supplied, otherwise ad-hoc signing.

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

The diagnostic tool reads input metadata and output controls. It does not query or control music players or record sound. The explicit `--exercise-duck` option briefly changes system sound and restores it afterward.

## Verification and limits

The suite contains 15 tests for output muting and restoration, manual overrides, output changes, saved recovery, cancellation, and independent sleep/lock holds. Native mute/restore was previously verified on this Mac; Apple Silicon builds still need execution on Apple Silicon hardware.

Input activity is polled every 200 ms. Very short input sessions can be missed; an app that holds its input open continuously keeps automatic muting active. Unknown input activity never counts as the end of microphone use. Muting and restoration run on a dedicated queue.

## License

MIT. See [LICENSE](LICENSE). Source code is available to read, build, modify, and redistribute. The Buy Me a Coffee badge is provided by its respective owner; see [asset notice](Resources/BuyMeACoffee-NOTICE.txt).

## Support MicYield

MicYield is free and open source. If it helps your work, you can optionally support its development with a coffee.

<a href="https://buymeacoffee.com/sosun"><img src="Resources/BuyMeACoffee.png" alt="Buy me a coffee" width="164" height="46"></a>

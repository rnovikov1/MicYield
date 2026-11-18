import SwiftUI
import MicYieldPlatform

/// The same status drives the menu-bar symbol and the panel. No audio work happens here.
struct AudioMenuStatus {
    let symbol: String
    let title: String
    let detail: String
    let needsAttention: Bool

    init(enabled: Bool, report: DuckingReport?) {
        needsAttention = enabled && report?.error != nil
        if !enabled {
            (symbol, title, detail) = ("speaker.wave.2", "Off", "Automatic muting is off")
        } else if report?.suspended == true {
            (symbol, title, detail) = ("pause.circle", "Monitoring paused", "Resumes when your Mac is active")
        } else if report?.error != nil {
            (symbol, title, detail) = ("exclamationmark.circle", "Audio needs attention", "See details below")
        } else if report?.silenced == true {
            (symbol, title, detail) = report?.microphoneActive == false
                ? ("speaker.slash", "Restoring sound", "Microphone is idle")
                : ("speaker.slash", "Audio muted", "Microphone in use")
        } else if report?.microphoneActive == true {
            (symbol, title, detail) = ("mic", "Microphone in use", "Monitoring audio output")
        } else if report?.microphoneActive == nil {
            (symbol, title, detail) = ("waveform", "Checking microphone", "Just a moment…")
        } else {
            (symbol, title, detail) = ("waveform", "Ready", "Microphone is idle")
        }
    }
}

struct MicYieldMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        MicYieldMenuContent(
            enabled: $model.enabled,
            report: model.report,
            loginEnabled: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }),
            loginNeedsApproval: model.loginState == .requiresApproval,
            loginError: model.loginError,
            openLoginSettings: model.openLoginSettings,
            quit: model.quit
        )
        .onAppear { model.refreshLoginState() }
    }
}

/// A side-effect-free surface, also used for native appearance and edge-state previews.
struct MicYieldMenuContent: View {
    @Binding var enabled: Bool
    var report: DuckingReport?
    @Binding var loginEnabled: Bool
    var loginNeedsApproval = false
    var loginError: String?
    var openLoginSettings: () -> Void
    var quit: () -> Void

    private let secondaryText = Color.primary.opacity(0.80)
    private var status: AudioMenuStatus { AudioMenuStatus(enabled: enabled, report: report) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: status.symbol)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(status.needsAttention ? Color.orange : Color.primary)
                    .frame(width: 30, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MicYield").font(.system(size: 15, weight: .semibold))
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            Text(status.title).fontWeight(.medium)
                            Text("·").accessibilityHidden(true)
                            Text(status.detail)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.title).fontWeight(.medium)
                            Text(status.detail)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(status.title). \(status.detail).")
                }
                Spacer(minLength: 0)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Toggle(isOn: $enabled) {
                    Text("Mute audio on mic use")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                    .font(.body.weight(.medium))
                    .help("Mute system audio whenever any app uses your microphone, including dictation and calls.")
                    .accessibilityHint("Music and videos continue silently. Sound returns after microphone use ends.")
                Text("Music and videos keep playing silently. Sound returns 0.8 seconds after mic use ends.")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = report?.error {
                    issue(error, recovery: "Check your audio device in Sound settings.")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Toggle(isOn: $loginEnabled) {
                    Text("Open at login")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                    .font(.body)
                    .help("Start MicYield when you sign in to your Mac.")
                    .accessibilityHint("Start MicYield automatically when you sign in to your Mac.")
                if loginNeedsApproval {
                    Text("Allow MicYield to start in Login Items.")
                        .font(.caption).foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Login Items…", action: openLoginSettings)
                        .controlSize(.small)
                }
                if let loginError {
                    issue(loginError, recovery: "Check MicYield in System Settings → General → Login Items.")
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 8) {
                Label("Local. No recording.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .help("Runs locally on your Mac. MicYield checks microphone activity without recording audio.")
                Spacer(minLength: 0)
                Button("Quit & restore sound", action: quit)
                    .keyboardShortcut("q")
                    .accessibilityLabel("Quit MicYield and restore sound")
                    .controlSize(.small)
                    .help("Quit MicYield and restore the sound it muted.")
                    .accessibilityHint("Restores any sound muted by MicYield before quitting.")
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(16)
        .frame(width: 340)
        .environment(\.locale, Locale(identifier: "en"))
    }

    private func issue(_ message: String, recovery: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(message).fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Text(recovery).foregroundStyle(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }
}

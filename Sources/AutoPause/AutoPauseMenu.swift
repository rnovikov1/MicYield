import SwiftUI
import AutoPauseCore
import AutoPausePlatform
import ServiceManagement

struct AutoPauseMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: model.menuSymbol)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(model.report?.microphoneActive == true ? Color.orange : Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AutoPause").font(.headline)
                    Text(model.status).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            settingToggle("Automatic audio control", description:
                "Pause Apple Music and Spotify when an app uses your microphone. Resume only music paused by AutoPause.",
                isOn: $model.enabled)
            settingToggle("Mute all other audio", description:
                "Silence YouTube and other apps during microphone use. Videos keep playing; your previous sound level returns afterward.",
                isOn: $model.duckingEnabled)
                .disabled(!model.enabled)

            Divider()
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Player.allCases, id: \.self) { player in playerRow(player) }
            }
            if let error = model.duckingReport?.error ?? model.report?.error {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Button("Open Automation Settings…", action: model.openAutomationSettings)
                .buttonStyle(.link)
                .help("Choose which music apps AutoPause can pause and resume.")

            Divider()
            settingToggle("Open at login", description:
                "Start AutoPause automatically when you sign in to your Mac.",
                isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
            if model.loginState == .requiresApproval {
                Button("Approve in Login Items…", action: model.openLoginSettings)
            }
            if let error = model.loginError {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Runs locally. Never records audio.")
                Text("Audio returns 0.8 s after microphone use ends.")
            }
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 12) {
                Text("Quitting stops all automatic audio control.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Quit AutoPause", action: model.quit)
                    .keyboardShortcut("q")
                    .help("Close AutoPause and restore any system sound it muted.")
            }
        }
        .padding(18)
        .frame(width: 380)
        .environment(\.locale, Locale(identifier: "en"))
        .onAppear { model.refreshLoginState() }
    }

    private func settingToggle(_ title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
    }

    private func playerRow(_ player: Player) -> some View {
        let permission = model.report?.permissions[player]
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(player.title).font(.subheadline.weight(.medium))
                Text(model.report?.owned.contains(player) == true ? "Paused by AutoPause" : permission?.title ?? "Checking access…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if permission == .needsConsent {
                Button(model.requesting == player ? "Requesting…" : "Allow Control") { model.requestPermission(player) }
                    .disabled(model.requesting != nil)
            } else if permission == .notRunning {
                Button("Open \(player.title)") { model.openPlayer(player) }
            } else if permission == .denied {
                Button("Open Settings", action: model.openAutomationSettings)
            } else if permission == .allowed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel("Playback control allowed")
            }
        }
    }
}

import SwiftUI
import MicYieldCore
import MicYieldPlatform
import ServiceManagement

struct MicYieldMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: model.menuSymbol)
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(model.report?.microphoneActive == true ? Color.orange : Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MicYield").font(.headline)
                    Text(model.status).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            settingToggle("Automatic audio muting", description:
                "Mute system audio while an app uses your microphone. Playback keeps going; your previous sound level returns afterward.",
                isOn: $model.enabled)
            if let error = model.report?.error {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            settingToggle("Open at login", description:
                "Start MicYield automatically when you sign in to your Mac.",
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
                Text("Quitting restores system sound.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Quit MicYield", action: model.quit)
                    .keyboardShortcut("q")
                    .help("Close MicYield and restore any system sound it muted.")
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

}

import SwiftUI
import AppKit
import ServiceManagement
import AutoPauseCore
import AutoPausePlatform

@MainActor
final class AppModel: ObservableObject {
    private var started = false
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "autoPauseEnabled")
            if started {
                worker.setEnabled(enabled)
                ducker.setEnabled(enabled && duckingEnabled)
            }
        }
    }
    @Published var duckingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(duckingEnabled, forKey: "systemAudioDuckingEnabled")
            if started { ducker.setEnabled(enabled && duckingEnabled) }
        }
    }
    @Published var duckingReport: DuckingReport?
    @Published var report: WorkerReport?
    @Published var requesting: Player?
    @Published var loginState = SMAppService.mainApp.status
    @Published var loginError: String?
    private var observations: [NSObjectProtocol] = []
    private var distributedObservations: [NSObjectProtocol] = []
    private lazy var worker = AutoPauseWorker { [weak self] report in
        Task { @MainActor [weak self] in self?.report = report }
    }

    private lazy var ducker = SystemAudioDucker { [weak self] report in
        Task { @MainActor [weak self] in self?.duckingReport = report }
    }

    init() {
        duckingEnabled = UserDefaults.standard.object(forKey: "systemAudioDuckingEnabled") as? Bool ?? true
        enabled = UserDefaults.standard.object(forKey: "autoPauseEnabled") as? Bool ?? true
        // Reject duplicates before starting workers, loading recovery records, or registering cleanup.
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.AutoPause")
        guard !running.contains(where: { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else { return }
        started = true
        worker.start(enabled: enabled)
        ducker.start(enabled: enabled && duckingEnabled)
        let audioCleanup = ducker
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in audioCleanup.stop() })
        let center = NSWorkspace.shared.notificationCenter
        observe(center, NSWorkspace.willSleepNotification, hold: true, reason: "sleep")
        observe(center, NSWorkspace.didWakeNotification, hold: false, reason: "sleep")
        observe(center, NSWorkspace.sessionDidResignActiveNotification, hold: true, reason: "session")
        observe(center, NSWorkspace.sessionDidBecomeActiveNotification, hold: false, reason: "session")
        for (name, suspended) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            let observation = DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.setSuspended(suspended, reason: "lock") }
            }
            distributedObservations.append(observation)
        }
        observations.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshLoginState() }
        })
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, hold: Bool, reason: String) {
        observations.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.setSuspended(hold, reason: reason) }
        })
    }

    private func setSuspended(_ suspended: Bool, reason: String) {
        worker.setSuspended(suspended, reason: reason)
        ducker.setSuspended(suspended, reason: reason)
    }

    var menuSymbol: String {
        if !enabled { return "pause.circle" }
        if report?.microphoneActive == true { return "mic.fill" }
        if report?.microphoneActive == nil || report?.error != nil || duckingReport?.error != nil { return "exclamationmark.circle" }
        return "waveform.circle"
    }
    var status: String {
        if !enabled { return "Automatic audio control is off" }
        if report?.suspended == true { return "Waiting for your Mac to unlock" }
        if report?.microphoneActive == nil { return "Checking microphone activity…" }
        if duckingReport?.silenced == true { return "System audio is muted" }
        if report?.microphoneActive == true {
            return report?.owned.isEmpty == false ? "Music paused by AutoPause" : "Microphone is in use"
        }
        if report?.owned.isEmpty == false { return "Restoring audio…" }
        return "Ready — microphone is not in use"
    }
    func requestPermission(_ player: Player) {
        guard requesting == nil else { return }
        requesting = player
        worker.requestPermission(player) { [weak self] in
            Task { @MainActor [weak self] in self?.requesting = nil }
        }
    }
    func openPlayer(_ player: Player) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") { NSWorkspace.shared.open(url) }
    }
    var loginEnabled: Bool { loginState == .enabled || loginState == .requiresApproval }
    func refreshLoginState() { loginState = SMAppService.mainApp.status }
    func setLoginEnabled(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { loginError = "Could not update Open at Login: \(error.localizedDescription)" }
        refreshLoginState()
    }
    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    func quit() { if started { ducker.stop() }; NSApplication.shared.terminate(nil) }
}

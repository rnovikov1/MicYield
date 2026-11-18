import SwiftUI
import AppKit
import ServiceManagement
import MicYieldCore
import MicYieldPlatform

@MainActor
final class AppModel: ObservableObject {
    private var started = false
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "automaticAudioMutingEnabled")
            if started {
                ducker.setEnabled(enabled)
            }
        }
    }
    @Published var report: DuckingReport?
    @Published var loginState = SMAppService.mainApp.status
    @Published var loginError: String?
    private var observations: [NSObjectProtocol] = []
    private var distributedObservations: [NSObjectProtocol] = []
    private lazy var ducker = SystemAudioDucker { [weak self] report in
        Task { @MainActor [weak self] in self?.report = report }
    }

    init() {
        let defaults = UserDefaults.standard
        // Preserve the old combined muting choice without changing legacy settings or recovery data.
        let previousControl = defaults.object(forKey: "autoPauseEnabled") as? Bool ?? true
        let previousMuting = defaults.object(forKey: "systemAudioDuckingEnabled") as? Bool ?? true
        enabled = defaults.object(forKey: "automaticAudioMutingEnabled") as? Bool ?? (previousControl && previousMuting)
        // Reject duplicates before starting workers, loading recovery records, or registering cleanup.
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.AutoPause")
        guard !running.contains(where: { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else { return }
        started = true
        ducker.start(enabled: enabled)
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
        ducker.setSuspended(suspended, reason: reason)
    }

    var menuSymbol: String { AudioMenuStatus(enabled: enabled, report: report).symbol }
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

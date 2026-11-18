import Foundation
import MicYieldCore

public struct WorkerReport: Equatable, Sendable {
    public var microphoneActive: Bool?
    public var owned: Set<Player>
    public var permissions: [Player: AutomationPermission]
    public var error: String?
    public var suspended: Bool
    public init(microphoneActive: Bool? = nil, owned: Set<Player> = [],
                permissions: [Player: AutomationPermission] = [:], error: String? = nil, suspended: Bool = false) {
        self.microphoneActive = microphoneActive
        self.owned = owned
        self.permissions = permissions
        self.error = error
        self.suspended = suspended
    }
}

/// All mutable state lives on queue; only Sendable reports leave the worker.
public final class MicYieldWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.AutoPause.monitor", qos: .utility)
    private let report: @Sendable (WorkerReport) -> Void
    private let gate = ControlGate()
    private lazy var media = MediaController(gate: gate)
    private lazy var engine = PauseEngine(media: media)
    private let microphone = MicrophoneReader()
    private var timer: DispatchSourceTimer?
    private var holds: Set<String> = []
    private var permissions: [Player: AutomationPermission] = [:]
    private var lastPermissionCheck: TimeInterval = -10
    private var lastReport: WorkerReport?

    public init(report: @escaping @Sendable (WorkerReport) -> Void) { self.report = report }
    public func start(enabled: Bool) {
        gate.setEnabled(enabled)
        queue.async { [self] in
            guard timer == nil else { return }
            engine.enabled = enabled
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(30))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }
    public func requestPermission(_ player: Player, completion: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            _ = media.permission(player, request: true)
            lastPermissionCheck = -10
            tick()
            completion()
        }
    }
    public func setEnabled(_ enabled: Bool) {
        gate.setEnabled(enabled)
        queue.async { self.engine.enabled = enabled; self.tick() }
    }
    public func setSuspended(_ suspended: Bool, reason: String) {
        gate.setSuspended(suspended, reason: reason)
        queue.async { [self] in
            if suspended { holds.insert(reason) } else { holds.remove(reason) }
            engine.reset()
            tick()
        }
    }
    public func stop() {
        gate.setEnabled(false)
        queue.async { [self] in timer?.cancel(); timer = nil; engine.reset() }
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionCheck >= 2 {
            for player in Player.allCases { permissions[player] = media.permission(player) }
            lastPermissionCheck = now
        }
        let activity = microphone.read()
        media.beginCycle()
        if holds.isEmpty { engine.update(microphone: activity.active, now: now) }
        let newReport = WorkerReport(microphoneActive: activity.active, owned: engine.ownedPlayers,
            permissions: permissions, error: activity.error ?? Player.allCases.compactMap { engine.errors[$0] }.first,
            suspended: !holds.isEmpty)
        if newReport != lastReport { lastReport = newReport; report(newReport) }
    }
}

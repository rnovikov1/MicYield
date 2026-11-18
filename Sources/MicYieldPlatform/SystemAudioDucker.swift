import Foundation
import MicYieldCore

public struct DuckingReport: Equatable, Sendable {
    public let microphoneActive: Bool?
    public let silenced: Bool
    public let error: String?
    public let suspended: Bool
    public init(microphoneActive: Bool? = nil, silenced: Bool = false, error: String? = nil, suspended: Bool = false) {
        self.microphoneActive = microphoneActive
        self.silenced = silenced
        self.error = error
        self.suspended = suspended
    }
}

/// Serial metadata monitoring and system-output muting; never controls another app.
public final class SystemAudioDucker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.AutoPause.output", qos: .userInitiated)
    private let gate = ControlGate()
    private var generation: UInt64?
    private lazy var output = SystemOutputController(maySilence: { [weak self] in
        guard let self else { return false }
        return gate.allows(generation)
    })
    private let report: @Sendable (DuckingReport) -> Void
    private let defaults: UserDefaults
    private let storageKey = "systemAudioLeases"
    private var holds: Set<String> = []
    private var timer: DispatchSourceTimer?
    private var lastReport: DuckingReport?
    private lazy var engine: DuckingEngine = {
        let saved = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode([OutputLease].self, from: $0) } ?? []
        return DuckingEngine(output: output, savedLeases: saved) { [defaults, storageKey] leases in
            if let data = try? JSONEncoder().encode(leases) { defaults.set(data, forKey: storageKey) }
        }
    }()

    public init(defaults: UserDefaults = .standard, report: @escaping @Sendable (DuckingReport) -> Void) {
        self.defaults = defaults
        self.report = report
    }
    public func start(enabled: Bool) {
        gate.setEnabled(enabled)
        queue.async { [self] in
            guard timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(20))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }
    public func setEnabled(_ enabled: Bool) {
        gate.setEnabled(enabled)
        queue.async { self.tick() }
    }
    public func setSuspended(_ suspended: Bool, reason: String) {
        gate.setSuspended(suspended, reason: reason)
        queue.async { [self] in
            if suspended { holds.insert(reason) } else { holds.remove(reason) }
            tick()
        }
    }
    public func stop() {
        gate.setEnabled(false)
        queue.sync {
            guard timer != nil else { return }
            timer?.cancel(); timer = nil; engine.restore()
        }
    }
    private func tick() {
        let activity = MicrophoneReader().read()
        generation = gate.capture()
        if generation != nil {
            engine.update(microphone: activity.active, now: ProcessInfo.processInfo.systemUptime)
        } else { engine.restore() }
        let value = DuckingReport(microphoneActive: activity.active, silenced: !engine.leases.isEmpty,
            error: activity.error ?? engine.error ?? output.warning, suspended: !holds.isEmpty)
        if value != lastReport { lastReport = value; report(value) }
    }
}

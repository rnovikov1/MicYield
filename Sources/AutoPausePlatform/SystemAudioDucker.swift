import Foundation
import AutoPauseCore

public struct DuckingReport: Equatable, Sendable {
    public let silenced: Bool
    public let error: String?
}

/// Independent from Apple Events: a blocked player or permission prompt cannot delay audio restore.
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
        queue.async { self.tick() }
    }
    public func stop() {
        gate.setEnabled(false)
        queue.sync {
            guard timer != nil else { return }
            timer?.cancel(); timer = nil; engine.restore()
        }
    }
    private func tick() {
        generation = gate.capture()
        if generation != nil {
            engine.update(microphone: MicrophoneReader().read().active, now: ProcessInfo.processInfo.systemUptime)
        } else { engine.restore() }
        let value = DuckingReport(silenced: !engine.leases.isEmpty, error: engine.error ?? output.warning)
        if value != lastReport { lastReport = value; report(value) }
    }
}

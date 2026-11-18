import Foundation

public struct OutputControlID: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case mute, volume }
    public let deviceUID: String
    public let kind: Kind
    public let channel: UInt32
    public init(deviceUID: String, kind: Kind, channel: UInt32 = 0) {
        self.deviceUID = deviceUID; self.kind = kind; self.channel = channel
    }
    public var silentValue: Double { kind == .mute ? 1 : 0 }
}
public struct OutputReading: Sendable {
    public let control: OutputControlID
    public let value: Double
    public init(control: OutputControlID, value: Double) { self.control = control; self.value = value }
}
public struct OutputLease: Codable, Sendable {
    public let control: OutputControlID
    public let original: Double
    public init(control: OutputControlID, original: Double) { self.control = control; self.original = original }
}
public protocol OutputControlling {
    func capture() throws -> [OutputReading]
    func read(_ control: OutputControlID) throws -> Double?
    func write(_ value: Double, to control: OutputControlID) throws
}
/// Single-queue ownership policy. Store original levels before mutation, never overwrite user changes.
public final class DuckingEngine {
    public private(set) var leases: [OutputLease]
    public private(set) var error: String?
    private let output: any OutputControlling
    private let save: ([OutputLease]) -> Void
    private var suppressed: Set<OutputControlID> = []
    private var quietSince: TimeInterval?
    private var sessionOpen = false

    public init(output: any OutputControlling, savedLeases: [OutputLease] = [], save: @escaping ([OutputLease]) -> Void = { _ in }) {
        self.output = output
        self.save = save
        leases = savedLeases.filter { $0.original.isFinite && (0...1).contains($0.original) && !$0.control.deviceUID.isEmpty }
    }

    public func update(microphone: Bool?, now: TimeInterval) {
        guard let microphone else { quietSince = nil; return }
        error = nil
        if microphone {
            sessionOpen = true
            quietSince = nil
            do {
                let readings = try output.capture()
                let active = Set(readings.map(\.control))
                restoreControls(leases.filter { !active.contains($0.control) })
                for reading in readings {
                    let control = reading.control
                    if leases.contains(where: { $0.control == control }) {
                        if !isSilent(reading.value, control) {
                            remove(control)
                            suppressed.insert(control)
                        }
                        continue
                    }
                    if isSilent(reading.value, control) {
                        // A pre-existing mute is not ours; let the user unmute it during this session.
                        suppressed.insert(control)
                        continue
                    }
                    guard !suppressed.contains(control), reading.value.isFinite,
                          (0...1).contains(reading.value) else { continue }
                    // Save first: even an ambiguous write failure must retain the original value.
                    leases.append(OutputLease(control: control, original: reading.value))
                    save(leases)
                    do { try output.write(control.silentValue, to: control) }
                    catch { self.error = error.localizedDescription }
                }
            } catch { self.error = error.localizedDescription }
        } else if sessionOpen || !leases.isEmpty {
            if quietSince == nil { quietSince = now }
            if let quietSince, now - quietSince >= 0.8 { restore() }
        }
    }

    public func restore() {
        error = nil
        restoreControls(leases)
        suppressed = []
        quietSince = nil
        sessionOpen = false
    }

    private func restoreControls(_ controls: [OutputLease]) {
        for lease in controls {
            do {
                // A detached device can return later with the same UID; retain the lease until then.
                guard let current = try output.read(lease.control) else { continue }
                if isSilent(current, lease.control) { try output.write(lease.original, to: lease.control) }
                remove(lease.control)
            } catch { self.error = error.localizedDescription }
        }
    }
    private func remove(_ control: OutputControlID) {
        leases.removeAll { $0.control == control }
        save(leases)
    }
    private func isSilent(_ value: Double, _ control: OutputControlID) -> Bool {
        value.isFinite && abs(value - control.silentValue) < 0.00001
    }
}

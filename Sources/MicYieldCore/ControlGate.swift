import Foundation

/// Invalidates queued audio writes immediately when disabled or suspended.
public final class ControlGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var enabled = true
    private var holds: Set<String> = []

    public init() {}
    public func capture() -> UInt64? {
        lock.withLock { enabled && holds.isEmpty ? generation : nil }
    }
    public func allows(_ token: UInt64?) -> Bool {
        lock.withLock { token != nil && token == generation && enabled && holds.isEmpty }
    }
    public func setEnabled(_ value: Bool) {
        lock.withLock {
            if enabled != value { enabled = value; generation &+= 1 }
        }
    }
    public func setSuspended(_ value: Bool, reason: String) {
        lock.withLock {
            let changed = value ? holds.insert(reason).inserted : holds.remove(reason) != nil
            if changed { generation &+= 1 }
        }
    }
}

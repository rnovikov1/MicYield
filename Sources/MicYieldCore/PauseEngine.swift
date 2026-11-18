import Foundation

public enum Player: String, CaseIterable, Sendable { case music, spotify }
public enum PlaybackState: Sendable { case playing, paused, stopped }

public struct PlaybackSnapshot: Equatable, Sendable {
    public var instance: String
    public var state: PlaybackState
    public var track: String
    public var position: Double

    public init(instance: String, state: PlaybackState, track: String, position: Double) {
        self.instance = instance
        self.state = state
        self.track = track
        self.position = position
    }

    public func matchesPause(_ pause: PlaybackSnapshot) -> Bool {
        state == .paused && instance == pause.instance && !track.isEmpty && track == pause.track
            && position.isFinite && pause.position.isFinite && abs(position - pause.position) <= 2
    }
}

/// Implementations must guard the expected snapshot again at the command boundary.
public protocol MediaControlling {
    func snapshot(_ player: Player) throws -> PlaybackSnapshot?
    func pause(_ player: Player, expected: PlaybackSnapshot) throws -> PlaybackSnapshot?
    func resume(_ player: Player, expected: PlaybackSnapshot) throws -> Bool
}

/// Owned by one serial worker. Time is monotonic; unknown input never means idle.
public final class PauseEngine {
    public var enabled = true { didSet { if !enabled { reset() } } }
    public var ownedPlayers: Set<Player> { Set(leases.keys) }
    public private(set) var errors: [Player: String] = [:]
    private let media: any MediaControlling
    private var leases: [Player: PlaybackSnapshot] = [:]
    private var attempted: Set<Player> = []
    private var quietSince: TimeInterval?
    private var sessionOpen = false

    public init(media: any MediaControlling) { self.media = media }

    public func update(microphone: Bool?, now: TimeInterval) {
        guard enabled else { return }
        guard let microphone else { quietSince = nil; return }
        if microphone {
            if !sessionOpen { attempted = []; sessionOpen = true }
            quietSince = nil
        } else {
            guard sessionOpen else { return }
            if quietSince == nil { quietSince = now }
        }

        for player in Player.allCases {
            guard microphone || leases[player] != nil else { continue }
            do {
                let current = try media.snapshot(player)
                errors[player] = nil
                if let lease = leases[player] {
                    if current?.matchesPause(lease) != true {
                        // User action, a different track, or a new player process cancels ownership.
                        leases[player] = nil
                    }
                } else if microphone, !attempted.contains(player), let current,
                          current.state == .playing, !current.track.isEmpty, current.position.isFinite {
                    attempted.insert(player)
                    if let paused = try media.pause(player, expected: current),
                       paused.state == .paused, paused.instance == current.instance,
                       paused.track == current.track, paused.position.isFinite {
                        leases[player] = paused
                    }
                }
            } catch {
                leases[player] = nil
                attempted.insert(player)
                errors[player] = error.localizedDescription
            }
        }

        if !microphone, let quietSince, now - quietSince >= 0.8 {
            // Consume first: a failed/ambiguous play must never be retried in a later session.
            let toResume = leases
            reset()
            for player in Player.allCases {
                guard let lease = toResume[player] else { continue }
                do { _ = try media.resume(player, expected: lease) }
                catch { errors[player] = error.localizedDescription }
            }
        }
    }

    public func reset() {
        leases = [:]
        attempted = []
        quietSince = nil
        sessionOpen = false
    }
}

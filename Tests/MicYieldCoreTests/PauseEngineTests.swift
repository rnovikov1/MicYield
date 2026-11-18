import Foundation
import MicYieldCore

final class MediaFixture: MediaControlling {
    var players: [Player: PlaybackSnapshot] = [:]
    var pauses: [Player] = []
    var resumes: [Player] = []
    var failPause = false
    var failSnapshot = false
    var failResume = false
    func snapshot(_ player: Player) throws -> PlaybackSnapshot? {
        if failSnapshot { throw CocoaError(.fileReadUnknown) }
        return players[player]
    }
    func pause(_ player: Player, expected: PlaybackSnapshot) throws -> PlaybackSnapshot? {
        if failPause { throw CocoaError(.fileReadUnknown) }
        guard players[player] == expected else { return nil }
        var paused = expected
        paused.state = .paused
        players[player] = paused
        pauses.append(player)
        return paused
    }
    func resume(_ player: Player, expected: PlaybackSnapshot) throws -> Bool {
        if failResume { throw CocoaError(.fileReadUnknown) }
        guard players[player] == expected else { return false }
        var playing = expected
        playing.state = .playing
        players[player] = playing
        resumes.append(player)
        return true
    }
}

final class PauseEngineTests {
    func setup(_ state: PlaybackState = .playing) -> (MediaFixture, PauseEngine) {
        let media = MediaFixture()
        media.players[.music] = PlaybackSnapshot(instance: "100:first", state: state, track: "track-A", position: 42)
        return (media, PauseEngine(media: media))
    }
    func finish(_ engine: PauseEngine) {
        engine.update(microphone: false, now: 1)
        engine.update(microphone: false, now: 2)
    }
    func testPausesPlayingAndResumesOwnedTrackAfterQuietDelay() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        try expectEqual(media.players[.music]?.state, .paused)
        try expectEqual(engine.ownedPlayers, [.music])
        engine.update(microphone: false, now: 1)
        engine.update(microphone: false, now: 1.7)
        try expectTrue(media.resumes.isEmpty)
        engine.update(microphone: false, now: 1.81)
        try expectEqual(media.resumes, [.music])
        engine.update(microphone: false, now: 3)
        try expectEqual(media.resumes.count, 1)
    }
    func testAlreadyPausedOrStoppedNeverStarts() throws {
        for state in [PlaybackState.paused, .stopped] {
            let (media, engine) = setup(state)
            engine.update(microphone: true, now: 0)
            finish(engine)
            try expectTrue(media.pauses.isEmpty)
            try expectTrue(media.resumes.isEmpty)
        }
    }
    func testSimultaneousPlayersAndLateStartingPlayerAreHandledIndependently() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.players[.spotify] = PlaybackSnapshot(instance: "200:first", state: .playing, track: "spotify:track:x", position: 9)
        engine.update(microphone: true, now: 0.2)
        finish(engine)
        try expectEqual(Set(media.pauses), [.music, .spotify])
        try expectEqual(Set(media.resumes), [.music, .spotify])
    }
    func testBriefGapAndSecondMicrophoneUserDoNotResume() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        engine.update(microphone: false, now: 1)
        engine.update(microphone: true, now: 1.5)
        engine.update(microphone: true, now: 5)
        try expectTrue(media.resumes.isEmpty)
        engine.update(microphone: false, now: 6)
        engine.update(microphone: false, now: 7)
        try expectEqual(media.resumes, [.music])
        try expectEqual(media.pauses.count, 1)
    }
    func testUnknownMicrophoneStateResetsQuietCountdown() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        engine.update(microphone: false, now: 1)
        engine.update(microphone: nil, now: 2)
        engine.update(microphone: false, now: 3)
        try expectTrue(media.resumes.isEmpty)
        engine.update(microphone: false, now: 4)
        try expectEqual(media.resumes, [.music])
    }
    func testManualResumeRelinquishesOwnershipAndDoesNotFightUser() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.players[.music]?.state = .playing
        engine.update(microphone: true, now: 0.2)
        finish(engine)
        try expectEqual(media.pauses.count, 1)
        try expectTrue(media.resumes.isEmpty)
        try expectTrue(engine.ownedPlayers.isEmpty)
    }
    func testTrackChangeSeekStopAndRelaunchPreventResume() throws {
        for mutation in 0..<4 {
            let (media, engine) = setup()
            engine.update(microphone: true, now: 0)
            switch mutation {
            case 0: media.players[.music]?.track = "track-B"
            case 1: media.players[.music]?.position = 80
            case 2: media.players[.music]?.state = .stopped
            default: media.players[.music]?.instance = "100:relaunch"
            }
            finish(engine)
            try expectTrue(media.resumes.isEmpty, "mutation \(mutation)")
        }
    }
    func testClosedPlayerNeverRelaunches() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.players.removeValue(forKey: .music)
        finish(engine)
        try expectTrue(media.resumes.isEmpty)
    }
    func testFailedPauseDoesNotCreateOwnership() throws {
        let (media, engine) = setup()
        media.failPause = true
        engine.update(microphone: true, now: 0)
        try expectTrue(engine.ownedPlayers.isEmpty)
        finish(engine)
        try expectTrue(media.resumes.isEmpty)
    }
    func testSnapshotFailureRevokesOwnership() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.failSnapshot = true
        engine.update(microphone: true, now: 0.2)
        media.failSnapshot = false
        finish(engine)
        try expectTrue(media.resumes.isEmpty)
    }
    func testResumeFailureIsNotRetriedLater() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.failResume = true
        finish(engine)
        media.failResume = false
        engine.update(microphone: false, now: 4)
        try expectTrue(media.resumes.isEmpty)
        try expectTrue(engine.ownedPlayers.isEmpty)
    }
    func testDisableAndResetLeaveMusicPaused() throws {
        for disable in [true, false] {
            let (media, engine) = setup()
            engine.update(microphone: true, now: 0)
            if disable { engine.enabled = false } else { engine.reset() }
            finish(engine)
            try expectTrue(media.resumes.isEmpty)
            try expectTrue(engine.ownedPlayers.isEmpty)
        }
    }
    func testNewCaptureSessionCanPauseAfterUserOverride() throws {
        let (media, engine) = setup()
        engine.update(microphone: true, now: 0)
        media.players[.music]?.state = .playing
        engine.update(microphone: true, now: 0.2)
        finish(engine)
        engine.update(microphone: true, now: 3)
        try expectEqual(media.pauses.count, 2)
    }
}

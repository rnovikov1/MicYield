import Foundation
import AutoPauseCore

final class OutputFixture: OutputControlling {
    let volume = OutputControlID(deviceUID: "speakers", kind: .volume)
    let headphones = OutputControlID(deviceUID: "headphones", kind: .mute)
    var values: [OutputControlID: Double] = [:]
    var active: [OutputControlID] = []
    var writes: [(OutputControlID, Double)] = []
    var failWrite = false
    var failRead = false
    init() { values[volume] = 0.62; values[headphones] = 0; active = [volume] }
    func capture() throws -> [OutputReading] {
        if failRead { throw CocoaError(.fileReadUnknown) }
        return active.compactMap { key in values[key].map { OutputReading(control: key, value: $0) } }
    }
    func read(_ control: OutputControlID) throws -> Double? {
        if failRead { throw CocoaError(.fileReadUnknown) }
        return values[control]
    }
    func write(_ value: Double, to control: OutputControlID) throws {
        if failWrite { throw CocoaError(.fileWriteUnknown) }
        values[control] = value
        writes.append((control, value))
    }
}

final class DuckingEngineTests {
    func finish(_ engine: DuckingEngine, start: Double = 1) {
        engine.update(microphone: false, now: start)
        engine.update(microphone: false, now: start + 0.81)
    }
    func testSilencesOutputThenRestoresExactOriginalVolume() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        try expectEqual(output.values[output.volume], 0)
        engine.update(microphone: true, now: 0.5)
        try expectEqual(engine.leases.count, 1)
        try expectEqual(output.writes.count, 1)
        engine.update(microphone: false, now: 1)
        engine.update(microphone: false, now: 1.7)
        try expectEqual(output.values[output.volume], 0)
        engine.update(microphone: false, now: 1.81)
        try expectEqual(output.values[output.volume], 0.62)
        try expectTrue(engine.leases.isEmpty)
    }
    func testExistingMuteOrZeroVolumeIsNotOwned() throws {
        let output = OutputFixture(); output.values[output.volume] = 0
        output.values[output.headphones] = 1; output.active.append(output.headphones)
        let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0); finish(engine)
        try expectTrue(output.writes.isEmpty)
        try expectEqual(output.values[output.headphones], 1)
    }
    func testMuteControlRestoresMuteFlagWithoutChangingVolume() throws {
        let output = OutputFixture(); output.active = [output.headphones]
        let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        try expectEqual(output.values[output.headphones], 1)
        finish(engine)
        try expectEqual(output.values[output.headphones], 0)
        try expectEqual(output.values[output.volume], 0.62)
    }
    func testManualVolumeChangeRelinquishesOwnershipForWholeSession() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        output.values[output.volume] = 0.21
        engine.update(microphone: true, now: 0.2)
        engine.update(microphone: true, now: 0.4); finish(engine)
        try expectEqual(output.values[output.volume], 0.21)
        try expectEqual(output.writes.count, 1)
    }
    func testManualChangeDuringQuietDelayIsPreserved() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        output.values[output.volume] = 0.33; finish(engine)
        try expectEqual(output.values[output.volume], 0.33)
    }
    func testMicrophoneGapAndUnknownStateCannotUnmute() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        engine.update(microphone: false, now: 1)
        engine.update(microphone: true, now: 1.5)
        engine.update(microphone: nil, now: 2)
        engine.update(microphone: false, now: 3)
        try expectEqual(output.values[output.volume], 0)
        engine.update(microphone: false, now: 3.81)
        try expectEqual(output.values[output.volume], 0.62)
    }
    func testDeviceSwitchRestoresOldAndSilencesNewOutput() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        output.active = [output.headphones]
        engine.update(microphone: true, now: 0.5)
        try expectEqual(output.values[output.volume], 0.62)
        try expectEqual(output.values[output.headphones], 1)
        finish(engine)
        try expectEqual(output.values[output.headphones], 0)
    }
    func testDisableQuitOrSuspendRestoresImmediately() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0); engine.restore()
        try expectEqual(output.values[output.volume], 0.62)
        try expectTrue(engine.leases.isEmpty)
    }
    func testFailedRestoreKeepsLeaseForRetry() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0); output.failWrite = true
        engine.restore()
        try expectEqual(engine.leases.count, 1)
        try expectTrue(engine.error != nil)
        output.failWrite = false; engine.restore()
        try expectEqual(output.values[output.volume], 0.62)
    }
    func testSavedLeaseRecoversOriginalVolumeAfterRestart() throws {
        let output = OutputFixture(); output.values[output.volume] = 0
        let lease = OutputLease(control: output.volume, original: 0.62)
        let engine = DuckingEngine(output: output, savedLeases: [lease])
        engine.restore()
        try expectEqual(output.values[output.volume], 0.62)
    }
    func testOriginalVolumeIsSavedBeforeMuteWrite() throws {
        let output = OutputFixture(); var saved: [OutputLease] = []; var savedBeforeWrite = false
        let engine = DuckingEngine(output: output, save: { leases in
            if !leases.isEmpty { savedBeforeWrite = output.values[output.volume] == 0.62 }
            saved = leases
        })
        engine.update(microphone: true, now: 0)
        try expectEqual(saved.first?.original, 0.62)
        try expectTrue(savedBeforeWrite)
        finish(engine); try expectTrue(saved.isEmpty)
    }
    func testUnreadableOutputCannotLoseOriginalVolume() throws {
        let output = OutputFixture(); let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0); output.failRead = true
        finish(engine)
        try expectEqual(engine.leases.count, 1)
        output.failRead = false; engine.restore()
        try expectEqual(output.values[output.volume], 0.62)
    }
    func testAlreadyMutedOutputCanBeManuallyUnmutedDuringCapture() throws {
        let output = OutputFixture(); output.active = [output.headphones]
        output.values[output.headphones] = 1
        let engine = DuckingEngine(output: output)
        engine.update(microphone: true, now: 0)
        output.values[output.headphones] = 0
        engine.update(microphone: true, now: 0.2)
        try expectEqual(output.values[output.headphones], 0)
        finish(engine)
        try expectEqual(output.values[output.headphones], 0)
    }

}

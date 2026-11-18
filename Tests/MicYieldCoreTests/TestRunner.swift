import Foundation

struct AssertionFailure: Error, CustomStringConvertible {
    let description: String
}
func expectTrue(_ value: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
    if !value { throw AssertionFailure(description: "\(file):\(line): expected true") }
}
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) throws {
    if actual != expected { throw AssertionFailure(description: "\(file):\(line): \(actual) != \(expected)") }
}

@main struct TestRunner {
    static func main() {
        let ducking = DuckingEngineTests()
        let platform = PlatformContractTests()
        let tests: [(String, () throws -> Void)] = [
            ("testAlreadyMutedOutputCanBeManuallyUnmutedDuringCapture", ducking.testAlreadyMutedOutputCanBeManuallyUnmutedDuringCapture),
            ("testSilencesOutputThenRestoresExactOriginalVolume", ducking.testSilencesOutputThenRestoresExactOriginalVolume),
            ("testExistingMuteOrZeroVolumeIsNotOwned", ducking.testExistingMuteOrZeroVolumeIsNotOwned),
            ("testMuteControlRestoresMuteFlagWithoutChangingVolume", ducking.testMuteControlRestoresMuteFlagWithoutChangingVolume),
            ("testManualVolumeChangeRelinquishesOwnershipForWholeSession", ducking.testManualVolumeChangeRelinquishesOwnershipForWholeSession),
            ("testManualChangeDuringQuietDelayIsPreserved", ducking.testManualChangeDuringQuietDelayIsPreserved),
            ("testMicrophoneGapAndUnknownStateCannotUnmute", ducking.testMicrophoneGapAndUnknownStateCannotUnmute),
            ("testDeviceSwitchRestoresOldAndSilencesNewOutput", ducking.testDeviceSwitchRestoresOldAndSilencesNewOutput),
            ("testDisableQuitOrSuspendRestoresImmediately", ducking.testDisableQuitOrSuspendRestoresImmediately),
            ("testFailedRestoreKeepsLeaseForRetry", ducking.testFailedRestoreKeepsLeaseForRetry),
            ("testSavedLeaseRecoversOriginalVolumeAfterRestart", ducking.testSavedLeaseRecoversOriginalVolumeAfterRestart),
            ("testOriginalVolumeIsSavedBeforeMuteWrite", ducking.testOriginalVolumeIsSavedBeforeMuteWrite),
            ("testUnreadableOutputCannotLoseOriginalVolume", ducking.testUnreadableOutputCannotLoseOriginalVolume),
            ("testDisableInvalidatesInFlightControlEvenAfterReenable", platform.testDisableInvalidatesInFlightControlEvenAfterReenable),
            ("testSleepAndLockHoldIndependently", platform.testSleepAndLockHoldIndependently)
        ]
        var failures = 0
        for (name, test) in tests {
            do { try test(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        print("\(tests.count - failures)/\(tests.count) passed")
        if failures > 0 { exit(1) }
    }
}

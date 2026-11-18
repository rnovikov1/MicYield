import Foundation
import MicYieldCore
import MicYieldPlatform

final class PlatformContractTests {
    func testDisableInvalidatesInFlightControlEvenAfterReenable() throws {
        let gate = ControlGate()
        let pending = gate.capture()
        gate.setEnabled(false)
        try expectTrue(!gate.allows(pending))
        gate.setEnabled(true)
        try expectTrue(!gate.allows(pending))
        try expectTrue(gate.allows(gate.capture()))
    }
    func testSleepAndLockHoldIndependently() throws {
        let gate = ControlGate()
        let pending = gate.capture()
        gate.setSuspended(true, reason: "sleep")
        gate.setSuspended(true, reason: "lock")
        gate.setSuspended(false, reason: "sleep")
        try expectTrue(gate.capture() == nil)
        try expectTrue(!gate.allows(pending))
        gate.setSuspended(false, reason: "lock")
        try expectTrue(gate.allows(gate.capture()))
        try expectTrue(!gate.allows(pending))
    }
}

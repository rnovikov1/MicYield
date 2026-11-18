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
    func testSpotifyCommandsComeFromItsOwnDictionary() throws {
        let xml = """
        <dictionary><suite name="Spotify" code="spfy">
          <command name="pause" code="spfyPaus"/>
          <command name="play" code="spfyPlay"/>
          <class name="track"><property name="id" code="ID  "/></class>
        </suite></dictionary>
        """
        let terms = try PlayerCommands(data: Data(xml.utf8), trackProperty: "id")
        try expectEqual(terms.pauseClass, 0x73706679)
        try expectEqual(terms.playClass, 0x73706679)
        try expectEqual(terms.pauseID, 0x50617573)
        try expectEqual(terms.playID, 0x506c6179)
        try expectEqual(terms.trackID, 0x49442020)
    }
    func testMusicCommandsMatchInstalledSystemDictionary() throws {
        let url = URL(fileURLWithPath: "/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef")
        let terms = try PlayerCommands(data: Data(contentsOf: url), trackProperty: "persistent ID")
        try expectEqual(terms.pauseClass, 0x686f6f6b)
        try expectEqual(terms.playClass, 0x686f6f6b)
        try expectEqual(terms.trackID, 0x70504953)
    }
    func testMalformedDictionaryCannotProduceCommands() throws {
        var rejected = false
        do { _ = try PlayerCommands(data: Data("<dictionary/>".utf8), trackProperty: "id") }
        catch { rejected = true }
        try expectTrue(rejected)
    }
}

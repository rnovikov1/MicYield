import Foundation
import CoreAudio

public struct MicrophoneActivity: Sendable {
    public let active: Bool?
    public let processIDs: [pid_t]
    public let error: String?
}

/// Reads metadata only. Never opens an audio stream or records samples.
public struct MicrophoneReader: Sendable {
    public init() {}
    public func read() -> MicrophoneActivity {
        do {
            let objects = try processObjects()
            var active: [pid_t] = []
            var uncertain: OSStatus?
            for object in objects {
                do {
                    if try uint32(object, kAudioProcessPropertyIsRunningInput) != 0 {
                        let pid = try? uint32(object, kAudioProcessPropertyPID)
                        active.append(pid_t(pid ?? 0))
                    }
                } catch let error as AudioReadError {
                    // A process may exit between enumeration and reading its properties.
                    if error.status != kAudioHardwareBadObjectError { uncertain = error.status }
                } catch { uncertain = -1 }
            }
            if !active.isEmpty { return MicrophoneActivity(active: true, processIDs: active, error: nil) }
            if let uncertain { throw AudioReadError(status: uncertain) }
            return MicrophoneActivity(active: false, processIDs: [], error: nil)
        } catch {
            return MicrophoneActivity(active: nil, processIDs: [], error: error.localizedDescription)
        }
    }

    private func processObjects() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        guard size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = objects.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!)
        }
        try check(status)
        return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value))
        return value
    }
    private func check(_ status: OSStatus) throws {
        if status != noErr { throw AudioReadError(status: status) }
    }
}

struct AudioReadError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Could not check microphone activity (error \(status)). Automatic audio muting is on hold." }
}

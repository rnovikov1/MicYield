import Foundation
import CoreAudio
import MicYieldCore

/// Controls the media and system default outputs using public Core Audio properties.
public final class SystemOutputController: OutputControlling {
    public private(set) var warning: String?
    private var devices: [String: AudioObjectID] = [:]
    private let maySilence: () -> Bool
    public init(maySilence: @escaping () -> Bool = { true }) { self.maySilence = maySilence }

    public func capture() throws -> [OutputReading] {
        warning = nil
        let system = AudioObjectID(kAudioObjectSystemObject)
        let output = try integer(system, kAudioHardwarePropertyDefaultOutputDevice)
        let alerts = try integer(system, kAudioHardwarePropertyDefaultSystemOutputDevice)
        var readings: [OutputReading] = []
        for device in Set([output, alerts]).filter({ $0 != kAudioObjectUnknown }).sorted() {
            let uid = try string(device, kAudioDevicePropertyDeviceUID)
            devices[uid] = device
            let controls = try controls(device, uid: uid)
            if controls.isEmpty {
                let name = (try? string(device, kAudioObjectPropertyName)) ?? uid
                warning = "The audio output “\(name)” does not support software muting or volume control."
            }
            for control in controls {
                if let value = try read(control) { readings.append(OutputReading(control: control, value: value)) }
            }
        }
        return readings
    }

    public func read(_ control: OutputControlID) throws -> Double? {
        guard let device = try resolve(control.deviceUID) else { return nil }
        var property = address(selector(control), scope: kAudioDevicePropertyScopeOutput, channel: control.channel)
        var size: UInt32 = 4
        if control.kind == .mute {
            var value: UInt32 = 0
            try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value))
            return Double(value)
        }
        var value: Float32 = 0
        try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value))
        return Double(value)
    }

    public func write(_ value: Double, to control: OutputControlID) throws {
        guard value.isFinite, (0...1).contains(value), let device = try resolve(control.deviceUID) else {
            throw OutputError.message("The audio output is unavailable. Its previous sound level is saved for restoration.")
        }
        guard value != control.silentValue || maySilence() else { throw OutputError.message("System muting was cancelled.") }
        var property = address(selector(control), scope: kAudioDevicePropertyScopeOutput, channel: control.channel)
        if control.kind == .mute {
            var level = UInt32(value.rounded())
            try check(AudioObjectSetPropertyData(device, &property, 0, nil, 4, &level))
        } else {
            var level = Float32(value)
            try check(AudioObjectSetPropertyData(device, &property, 0, nil, 4, &level))
        }
    }

    private func controls(_ device: AudioObjectID, uid: String) throws -> [OutputControlID] {
        func writable(_ kind: OutputControlID.Kind, _ channel: UInt32) -> OutputControlID? {
            let key = OutputControlID(deviceUID: uid, kind: kind, channel: channel)
            var property = address(selector(key), scope: kAudioDevicePropertyScopeOutput, channel: channel)
            var settable: DarwinBoolean = false
            guard AudioObjectHasProperty(device, &property),
                  AudioObjectIsPropertySettable(device, &property, &settable) == noErr, settable.boolValue else { return nil }
            return key
        }
        if let master = writable(.mute, 0) ?? writable(.volume, 0) { return [master] }
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(device, &property, 0, nil, &size))
        guard size >= MemoryLayout<AudioBufferList>.size else { return [] }
        let bytes = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bytes.deallocate() }
        try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, bytes))
        let buffers = UnsafeMutableAudioBufferListPointer(bytes.assumingMemoryBound(to: AudioBufferList.self))
        let count = buffers.reduce(UInt32(0)) { $0 + $1.mNumberChannels }
        guard count > 0, count <= 64 else { return [] }
        var result: [OutputControlID] = []
        for channel in 1...count {
            guard let control = writable(.mute, channel) ?? writable(.volume, channel) else { return [] }
            result.append(control)
        }
        return result
    }

    private func resolve(_ uid: String) throws -> AudioObjectID? {
        if let device = devices[uid], (try? string(device, kAudioDevicePropertyDeviceUID)) == uid { return device }
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        try check(AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size))
        guard size > 0 else { return nil }
        var all = [AudioObjectID](repeating: 0, count: Int(size) / 4)
        let status = all.withUnsafeMutableBytes { AudioObjectGetPropertyData(system, &property, 0, nil, &size, $0.baseAddress!) }
        try check(status)
        for device in all.prefix(Int(size) / 4) {
            if (try? string(device, kAudioDevicePropertyDeviceUID)) == uid { devices[uid] = device; return device }
        }
        return nil
    }
    private func selector(_ control: OutputControlID) -> AudioObjectPropertySelector {
        control.kind == .mute ? kAudioDevicePropertyMute : kAudioDevicePropertyVolumeScalar
    }
    private func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, channel: UInt32 = 0) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: channel)
    }
    private func integer(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> UInt32 {
        var property = address(selector)
        var value: UInt32 = 0; var size: UInt32 = 4
        try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value))
        return value
    }
    private func string(_ device: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var property = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value))
        guard let value else { throw OutputError.message("Could not identify the audio output.") }
        return value.takeRetainedValue() as String
    }
    private func check(_ status: OSStatus) throws {
        if status != noErr { throw OutputError.message("Could not change the sound level (error \(status)). Check your audio output.") }
    }
}
private enum OutputError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { value } else { nil } }
}

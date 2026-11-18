import Foundation
import MicYieldCore
import MicYieldPlatform

let reader = MicrophoneReader()
let arguments = CommandLine.arguments
let watchIndex = arguments.firstIndex(of: "--watch")
let seconds = watchIndex.flatMap { index in arguments.indices.contains(index + 1) ? Double(arguments[index + 1]) : nil } ?? 0
if watchIndex != nil, seconds <= 0 || seconds > 300 {
    print("Usage: MicYieldDiagnostics [--watch 1...300] [--outputs] [--exercise-duck]")
    exit(2)
}
print("MicYield diagnostics; metadata only, no audio capture or permission prompts")
print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
let deadline = ProcessInfo.processInfo.systemUptime + seconds
var previous: String?
repeat {
    let activity = reader.read()
    let status = activity.active.map { $0 ? "ACTIVE" : "IDLE" } ?? "UNKNOWN"
    let line = "microphone=\(status) inputPIDs=\(activity.processIDs) error=\(activity.error ?? "none")"
    if line != previous {
        print("\(Date().ISO8601Format()) \(line)")
        previous = line
    }
    if seconds > 0 { Thread.sleep(forTimeInterval: 0.2) }
} while ProcessInfo.processInfo.systemUptime < deadline
if reader.read().active == nil { exit(1) }

if arguments.contains("--outputs") || arguments.contains("--exercise-duck") {
    do {
        let outputs = SystemOutputController()
        let before = try outputs.capture()
        for value in before { print("output=\(value.control.deviceUID) control=\(value.control.kind.rawValue):\(value.control.channel) value=\(value.value)") }
        if let warning = outputs.warning { print(warning) }
        if arguments.contains("--exercise-duck") {
            guard !before.isEmpty, reader.read().active == false else {
                print("Cannot exercise ducking: output unavailable or microphone not idle")
                exit(2)
            }
            let engine = DuckingEngine(output: outputs)
            defer { engine.restore() }
            engine.update(microphone: true, now: 0)
            let during = try outputs.capture()
            guard during.count == before.count,
                  during.allSatisfy({ abs($0.value - $0.control.silentValue) < 0.00001 }), engine.error == nil else {
                throw NSError(domain: "MicYield", code: 1, userInfo: [NSLocalizedDescriptionKey: engine.error ?? "Output did not become silent"])
            }
            print("PASS native silence: \(engine.leases.count) owned control(s)")
            engine.update(microphone: false, now: 1)
            engine.update(microphone: false, now: 2)
            for value in before {
                guard let restored = try outputs.read(value.control), abs(restored - value.value) < 0.00001 else {
                    throw NSError(domain: "MicYield", code: 2, userInfo: [NSLocalizedDescriptionKey: "Original output level was not restored"])
                }
            }
            print("PASS native restore: all output levels match their original values")
        }
    } catch {
        print("Output check failed: \(error.localizedDescription)")
        exit(1)
    }
}

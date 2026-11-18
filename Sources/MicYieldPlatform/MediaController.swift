import AppKit
import ApplicationServices
import MicYieldCore

/// Serial worker only. Events target an existing PID, so a quit player is never relaunched.
public final class MediaController: MediaControlling {
    private let gate: ControlGate
    private var generation: UInt64?
    public init(gate: ControlGate = ControlGate()) { self.gate = gate; generation = gate.capture() }
    public func beginCycle() { generation = gate.capture() }

    public func permission(_ player: Player, request: Bool = false) -> AutomationPermission {
        guard let app = running(player) else {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) == nil
                ? .notInstalled : .notRunning
        }
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        guard let descriptor = target.aeDesc else { return .failed(-1) }
        let status = AEDeterminePermissionToAutomateTarget(descriptor,
            AEEventClass(typeWildCard), AEEventID(typeWildCard), request)
        switch status {
        case noErr: return .allowed
        case OSStatus(errAEEventWouldRequireUserConsent): return .needsConsent
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(procNotFound): return .notRunning
        default: return .failed(status)
        }
    }

    public func snapshot(_ player: Player) throws -> PlaybackSnapshot? {
        guard let app = running(player) else { return nil }
        guard permission(player) == .allowed else { throw MediaError.message("\(player.title): \(permission(player).title)") }
        return try snapshot(player, app: app)
    }

    public func pause(_ player: Player, expected: PlaybackSnapshot) throws -> PlaybackSnapshot? {
        guard let app = running(player), identity(app) == expected.instance,
              let current = try snapshot(player, app: app), current.state == .playing,
              current.track == expected.track, abs(current.position - expected.position) <= 2 else { return nil }
        let commands = try commands(player, app: app)
        guard gate.allows(generation) else { return nil }
        _ = try send(app: app, eventClass: commands.pauseClass, eventID: commands.pauseID)
        guard let paused = try snapshot(player, app: app), paused.state == .paused,
              paused.track == expected.track, paused.instance == expected.instance else { return nil }
        return paused
    }

    public func resume(_ player: Player, expected: PlaybackSnapshot) throws -> Bool {
        guard let app = running(player), identity(app) == expected.instance,
              let current = try snapshot(player, app: app), current.matchesPause(expected),
              MicrophoneReader().read().active == false else { return false }
        let commands = try commands(player, app: app)
        guard gate.allows(generation) else { return false }
        _ = try send(app: app, eventClass: commands.playClass, eventID: commands.playID)
        return true
    }

    private func running(_ player: Player) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID).first { !$0.isTerminated }
    }
    private func identity(_ app: NSRunningApplication) -> String {
        "\(app.processIdentifier):\(app.launchDate?.timeIntervalSince1970 ?? 0)"
    }

    private func snapshot(_ player: Player, app: NSRunningApplication) throws -> PlaybackSnapshot? {
        guard !app.isTerminated else { return nil }
        let stateCode = try get(code("pPlS"), app: app).enumCodeValue
        let state: PlaybackState
        switch stateCode {
        case code("kPSP"): state = .playing
        case code("kPSp"): state = .paused
        default: state = .stopped
        }
        if state == .stopped { return PlaybackSnapshot(instance: identity(app), state: state, track: "", position: 0) }
        let trackProperty = try commands(player, app: app).trackID
        let trackObject = try property(code("pTrk"))
        let track = try get(trackProperty, app: app, container: trackObject).stringValue ?? ""
        let positionDescriptor = try get(code("pPos"), app: app)
        guard let numeric = positionDescriptor.coerce(toDescriptorType: typeIEEE64BitFloatingPoint) else {
            throw MediaError.message("\(player.title): could not read the playback position.")
        }
        // Detect a track switch during the multi-event snapshot.
        let confirmedTrack = try get(trackProperty, app: app, container: trackObject).stringValue ?? ""
        guard track == confirmedTrack, !app.isTerminated else { return nil }
        return PlaybackSnapshot(instance: identity(app), state: state, track: track, position: numeric.doubleValue)
    }

    private var cachedCommands: [Player: PlayerCommands] = [:]
    private func commands(_ player: Player, app: NSRunningApplication) throws -> PlayerCommands {
        if let cached = cachedCommands[player] { return cached }
        guard let url = app.bundleURL, let bundle = Bundle(url: url),
              let name = bundle.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String,
              let resource = bundle.resourceURL?.appendingPathComponent(name) else {
            throw MediaError.message("\(player.title): playback controls are unavailable.")
        }
        let result = try PlayerCommands(data: Data(contentsOf: resource),
            trackProperty: player == .music ? "persistent ID" : "id")
        cachedCommands[player] = result
        return result
    }

    private func property(_ propertyCode: UInt32, container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        record.setDescriptor(NSAppleEventDescriptor(typeCode: propertyCode), forKeyword: AEKeyword(keyAEKeyData))
        record.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        guard let object = record.coerce(toDescriptorType: typeObjectSpecifier) else {
            throw MediaError.message("Could not send a playback command. Try restarting MicYield.")
        }
        return object
    }

    private func get(_ propertyCode: UInt32, app: NSRunningApplication,
                     container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        try send(app: app, eventClass: kAECoreSuite, eventID: kAEGetData,
                 object: property(propertyCode, container: container))
    }

    private func send(app: NSRunningApplication, eventClass: UInt32, eventID: UInt32,
                      object: NSAppleEventDescriptor? = nil) throws -> NSAppleEventDescriptor {
        guard !app.isTerminated else { throw MediaError.message("The music app has closed.") }
        let event = NSAppleEventDescriptor(eventClass: eventClass, eventID: eventID,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: app.processIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        if let object { event.setParam(object, forKeyword: keyDirectObject) }
        let options = NSAppleEventDescriptor.SendOptions(rawValue:
            NSAppleEventDescriptor.SendOptions.waitForReply.rawValue |
            NSAppleEventDescriptor.SendOptions.neverInteract.rawValue | UInt(kAEDoNotPromptForUserConsent))
        let reply = try event.sendEvent(options: options, timeout: 2)
        if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
            let message = reply.paramDescriptor(forKeyword: keyErrorString)?.stringValue ?? "Apple Event"
            throw MediaError.message("\(message) (\(error.int32Value))")
        }
        return reply.paramDescriptor(forKeyword: keyDirectObject) ?? .null()
    }
}


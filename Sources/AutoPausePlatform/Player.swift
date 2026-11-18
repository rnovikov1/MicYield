import Foundation
import AutoPauseCore

extension Player {
    public var title: String { self == .music ? "Apple Music" : "Spotify" }
    public var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
}

public enum AutomationPermission: Equatable, Sendable {
    case allowed, needsConsent, denied, notRunning, notInstalled, failed(Int32)
    public var title: String {
        switch self {
        case .allowed: "Playback control allowed"
        case .needsConsent: "Allow access to pause and resume"
        case .denied: "Access denied in System Settings"
        case .notRunning: "Not running"
        case .notInstalled: "Not installed"
        case .failed(let code): "Could not check access. Error: \(code)"
        }
    }
}

enum MediaError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let message): message } }
}

func code(_ value: String) -> UInt32 {
    precondition(value.utf8.count == 4)
    return value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
}

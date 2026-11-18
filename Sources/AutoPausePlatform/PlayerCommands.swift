import Foundation

/// Terminology is read from the installed player's own sdef; no network or guessed Spotify codes.
public struct PlayerCommands: Sendable {
    public let pauseClass: UInt32
    public let pauseID: UInt32
    public let playClass: UInt32
    public let playID: UInt32
    public let trackID: UInt32

    public init(data: Data, trackProperty: String) throws {
        let xml = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        func value(_ path: String, bytes: Int) throws -> String {
            guard let value = try xml.nodes(forXPath: path).first?.stringValue,
                  value.utf8.count == bytes else { throw MediaError.message("This app does not provide the playback controls AutoPause needs.") }
            return value
        }
        let pause = try value("//command[@name='pause']/@code", bytes: 8)
        let play = try value("//command[@name='play']/@code", bytes: 8)
        let track = try value("//property[@name='\(trackProperty)']/@code", bytes: 4)
        pauseClass = code(String(pause.prefix(4)))
        pauseID = code(String(pause.suffix(4)))
        playClass = code(String(play.prefix(4)))
        playID = code(String(play.suffix(4)))
        trackID = code(track)
    }
}

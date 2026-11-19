import Foundation

/// Auto-save per game, so players can leave mid-game and resume with no penalty.
enum Save {
    static var dir = URL.applicationSupportDirectory.appending(path: "saves")

    static func store<T: Encodable>(_ gameID: String, _ data: T) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // Atomic: written to a temp file then renamed, so a crash mid-write can't corrupt the save.
            try JSONEncoder().encode(data).write(to: path(gameID), options: .atomic)
        } catch {
            print("Save failed for \(gameID): \(error)")
        }
    }

    /// nil when there is no save or it can't be read.
    static func load<T: Decodable>(_ gameID: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: path(gameID)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func clear(_ gameID: String) {
        try? FileManager.default.removeItem(at: path(gameID))
    }

    private static func path(_ gameID: String) -> URL { dir.appending(path: "\(gameID).json") }
}

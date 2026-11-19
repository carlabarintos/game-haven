import Foundation

/// Jigsaw rules: cut a picture into a square of pieces, and place each one in its own spot. Pieces never turn.
/// Pieces and spots are numbered in row order, 0 at the top left, and piece k belongs in spot k.
nonisolated enum JigsawLogic {
    enum Level: String, CaseIterable, Codable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        /// Pieces along each side.
        var size: Int {
            switch self {
            case .easy: 3
            case .medium: 4
            case .hard: 5
            }
        }
        var pieces: Int { size * size }
        /// How strongly the faint copy of the picture shows in the frame.
        var guide: Double {
            switch self {
            case .easy: 0.35
            case .medium: 0.2
            case .hard: 0
            }
        }
    }

    /// The pictures' names, in the order of the bundled images jigsaw-0, jigsaw-1, … (see JigsawPicture).
    static let pictures = ["Cherry Blossom River", "Plum Garden", "Autumn Moon", "Twilight Bridge"]

    /// A fresh puzzle: random tab shapes and a shuffled tray, the same for the same seed.
    static func generate(_ level: Level, picture: Int, seed: UInt64) -> JigsawGame {
        var rng = SplitMix64(seed: seed)
        let n = level.size
        return JigsawGame(
            level: level, picture: picture,
            across: (0..<n * (n - 1)).map { _ in Bool.random(using: &rng) },
            down: (0..<n * (n - 1)).map { _ in Bool.random(using: &rng) },
            loose: Array(0..<n * n).shuffled(using: &rng))
    }
}

/// One saved jigsaw.
nonisolated struct JigsawGame: Codable {
    let level: JigsawLogic.Level
    let picture: Int
    /// Tab on each inside edge between side-by-side pieces, row by row: true sticks out to the right, false to the left.
    let across: [Bool]
    /// Tab on each inside edge between stacked pieces, row by row: true sticks out downwards.
    let down: [Bool]
    /// Pieces still in the tray, in the order it shows them.
    var loose: [Int]

    var size: Int { level.size }
    var solved: Bool { loose.isEmpty }
    func isPlaced(_ piece: Int) -> Bool { !loose.contains(piece) }

    /// Easy 1, medium 2, hard 3. Hints never cost a star.
    var stars: Int { JigsawLogic.Level.allCases.firstIndex(of: level)! + 1 }

    /// Each side's edge, clockwise from the top: 0 flat (the picture's border), 1 a tab sticking out, -1 a hole.
    func edges(_ piece: Int) -> [Int] {
        let n = size, r = piece / n, c = piece % n
        func tab(_ out: Bool) -> Int { out ? 1 : -1 }
        return [
            r == 0 ? 0 : -tab(down[(r - 1) * n + c]),
            c == n - 1 ? 0 : tab(across[r * (n - 1) + c]),
            r == n - 1 ? 0 : tab(down[r * n + c]),
            c == 0 ? 0 : -tab(across[r * (n - 1) + c - 1]),
        ]
    }

    /// Puts the piece in the spot if it belongs there. Returns whether it went in.
    mutating func place(_ piece: Int, at spot: Int) -> Bool {
        guard piece == spot, let i = loose.firstIndex(of: piece) else { return false }
        loose.remove(at: i)
        return true
    }
}

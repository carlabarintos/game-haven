import Foundation

/// Mahjong solitaire rules: tiles stacked in layers, cleared in matching pairs.
/// Positions are in half-tile steps, so a tile spans two steps each way and an upper layer can sit half a tile over.
nonisolated enum MahjongLogic {
    enum Level: String, CaseIterable, Codable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        /// Each layer's columns and rows, bottom first, centred on the one below. Small enough that a phone shows big tiles.
        var layers: [(cols: Int, rows: Int)] {
            switch self {
            case .easy: [(6, 4), (4, 2)]
            case .medium: [(7, 6), (6, 5), (3, 2)]
            case .hard: [(8, 7), (7, 6), (4, 3), (2, 1)]
            }
        }
        var tiles: Int { layers.reduce(0) { $0 + $1.cols * $1.rows } }
    }

    /// 9 dots, 9 bamboo, 9 characters, 4 winds, 3 dragons.
    static let faces = 34

    static func name(_ face: Int) -> String {
        switch face {
        case 0..<9: "\(face + 1) dots"
        case 9..<18: "\(face - 8) bamboo"
        case 18..<27: "\(face - 17) characters"
        case 27..<31: ["East", "South", "West", "North"][face - 27] + " wind"
        default: ["Red", "Green", "White"][face - 31] + " dragon"
        }
    }

    static func layout(_ level: Level) -> [MahjongGame.Tile] {
        let base = level.layers[0]
        return level.layers.enumerated().flatMap { z, layer in
            (0..<layer.rows).flatMap { r in
                (0..<layer.cols).map { c in
                    MahjongGame.Tile(x: base.cols - layer.cols + 2 * c, y: base.rows - layer.rows + 2 * r, z: z, face: 0)
                }
            }
        }
    }

    /// A new game. Every face is used once before any repeats, so Easy has no look-alike pairs.
    static func generate(_ level: Level, seed: UInt64) -> MahjongGame {
        var rng = SplitMix64(seed: seed)
        var g = MahjongGame(level: level, tiles: layout(level))
        let kinds = Array(0..<faces).shuffled(using: &rng)
        let pairs = (0..<level.tiles / 2).map { kinds[$0 % faces] }
        while !g.deal(Set(g.tiles.indices), pairs: pairs, using: &rng) {}
        return g
    }
}

/// One saved game.
nonisolated struct MahjongGame: Codable {
    struct Tile: Codable, Equatable {
        let x: Int, y: Int, z: Int
        var face: Int
    }

    let level: MahjongLogic.Level
    /// Every tile, cleared or not; a tile's index is its id.
    var tiles: [Tile]
    var gone: Set<Int> = []
    /// Pairs cleared, oldest first, for undo.
    var history: [[Int]] = []

    var left: [Int] { tiles.indices.filter { !gone.contains($0) } }
    var won: Bool { gone.count == tiles.count }
    /// Easy 1, medium 2, hard 3. Hints, undo and shuffles never cost a star.
    var stars: Int { MahjongLogic.Level.allCases.firstIndex(of: level)! + 1 }

    /// Another tile lies over part of it.
    func covered(_ i: Int, among spots: Set<Int>? = nil) -> Bool {
        let t = tiles[i]
        return (spots ?? Set(left)).contains { tiles[$0].z == t.z + 1 && abs(tiles[$0].x - t.x) < 2 && abs(tiles[$0].y - t.y) < 2 }
    }

    /// Nothing on top, and an open left or right side.
    func free(_ i: Int, among spots: Set<Int>? = nil) -> Bool {
        let spots = spots ?? Set(left)
        guard spots.contains(i), !covered(i, among: spots) else { return false }
        let t = tiles[i]
        func side(_ dx: Int) -> Bool { spots.contains { tiles[$0].z == t.z && tiles[$0].x == t.x + dx && abs(tiles[$0].y - t.y) < 2 } }
        return !side(-2) || !side(2)
    }

    /// Clears a and b if both are free and match.
    mutating func match(_ a: Int, _ b: Int) -> Bool {
        guard a != b, free(a), free(b), tiles[a].face == tiles[b].face else { return false }
        gone.formUnion([a, b])
        history.append([a, b])
        return true
    }

    mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        gone.subtract(last)
        return true
    }

    /// A free matching pair, or nil when the player is stuck.
    var hint: (Int, Int)? {
        let free = left.filter { self.free($0) }
        for (k, a) in free.enumerated() {
            if let b = free[(k + 1)...].first(where: { tiles[$0].face == tiles[a].face }) { return (a, b) }
        }
        return nil
    }

    /// Mixes the faces still on the board into a layout that can be cleared. False if none can be found.
    mutating func shuffle(seed: UInt64) -> Bool {
        var rng = SplitMix64(seed: seed)
        let faces = left.map { tiles[$0].face }.sorted()
        let pairs = stride(from: 0, to: faces.count, by: 2).map { faces[$0] }
        for _ in 0..<200 {
            if deal(Set(left), pairs: pairs, using: &rng) { return true }
        }
        return false
    }

    /// Gives one face per pair to the tiles at spots by taking free pairs off at random, last pair first.
    /// Playing those steps backwards clears the board, so the deal can always be won. False if it got stuck, faces untouched.
    mutating func deal(_ spots: Set<Int>, pairs: [Int], using rng: inout SplitMix64) -> Bool {
        var spots = spots
        var faces: [Int: Int] = [:]
        for face in pairs.shuffled(using: &rng) {
            let free = spots.sorted().filter { self.free($0, among: spots) }.shuffled(using: &rng)  // sorted: a Set's order changes every launch
            guard free.count >= 2 else { return false }
            faces[free[0]] = face
            faces[free[1]] = face
            spots.subtract(free.prefix(2))
        }
        for (i, face) in faces { tiles[i].face = face }
        return true
    }
}

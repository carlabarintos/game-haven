import Foundation

/// Draw dominoes against the computer with a double-six set: match an open end, draw from the pile when you can't.
/// First to empty their hand wins; if nobody can play, the lower pip count wins.
nonisolated enum DominoLogic {
    enum Level: String, CaseIterable, Codable {
        /// Easy plays its first tile that fits; Hard sheds its heaviest tiles first.
        case easy = "Easy", hard = "Hard"
    }

    static let set: [Domino] = (0...6).flatMap { a in (a...6).map { Domino(a: a, b: $0) } }

    /// Seven tiles each, the rest in the pile. If the computer holds the highest double, it opens with it.
    static func generate(_ level: Level, seed: UInt64) -> DominoGame {
        var rng = SplitMix64(seed: seed)
        let tiles = set.shuffled(using: &rng)
        var g = DominoGame(level: level, board: .init(line: [], you: Array(tiles[0..<7]), computer: Array(tiles[7..<14]), pile: Array(tiles[14...])))
        let doubles = (g.board.you + g.board.computer).filter(\.double)
        if let top = doubles.max(by: { $0.a < $1.a }), let i = g.board.computer.firstIndex(of: top) {
            g.board.line = [g.board.computer.remove(at: i)]
            g.board.said = "The computer opened with the double \(top.a)."
        }
        return g
    }
}

nonisolated extension DominoLogic {
    /// Where a tile sits on the table: its centre in units of half a tile, around the first tile played.
    /// `flipped` draws b first (on the left, or on top).
    struct Spot {
        var x: Double, y: Double
        var vertical: Bool
        var flipped: Bool
    }

    /// Lays the line out like a real table: the first tile in the middle, doubles crosswise, the right arm
    /// growing rightwards and the left arm leftwards. At the edge an arm turns with an upright tile and runs back,
    /// the right arm stepping down and the left arm up, so the arms never meet. Placed tiles never move.
    static func layout(_ line: [Domino], first: Int, width: Double) -> [Spot] {
        guard line.indices.contains(first) else { return [] }
        var spots = Array(repeating: Spot(x: 0, y: 0, vertical: false, flipped: false), count: line.count)
        spots[first].vertical = line[first].double
        for arm in [1.0, -1.0] {
            var d = arm, cursor = arm * (line[first].double ? 0.5 : 1), row = 0.0
            let outward = arm > 0 ? Array(line.indices[(first + 1)...]) : Array(line.indices[..<first].reversed())
            for i in outward {
                let length = line[i].double ? 1.0 : 2.0
                if abs(cursor + d * length) + 1 > width / 2 {  // no room for this tile and a turn after it: turn now
                    // Upright beside the end, top half level with this row and bottom half level with the next.
                    spots[i] = Spot(x: cursor + d / 2, y: row + arm, vertical: true, flipped: false)  // a on top: the right arm goes down from a, the left arm up to b
                    row += arm * 2
                    d = -d
                    continue
                }
                let double = line[i].double
                spots[i] = Spot(x: cursor + d * length / 2, y: row, vertical: double, flipped: !double && d != arm)
                cursor += d * length
            }
        }
        return spots
    }
}

nonisolated struct Domino: Codable, Hashable {
    var a: Int, b: Int
    var pips: Int { a + b }
    var double: Bool { a == b }
    var flipped: Domino { Domino(a: b, b: a) }
    var name: String { double ? "double \(a)" : "\(a) and \(b)" }
}

/// One saved game.
nonisolated struct DominoGame: Codable {
    enum Side: String, Codable { case left, right }
    enum Result { case won, lost, tie }

    struct Board: Codable {
        /// Left to right; each tile's b touches the next tile's a.
        var line: [Domino]
        /// Tiles played on the left, so line[left] is the first tile played, which stays put in the middle of the table.
        var left = 0
        var you: [Domino]
        var computer: [Domino]
        var pile: [Domino]
        /// Passes in a row; two means nobody can play.
        var passes = 0
        /// What the computer just did.
        var said: String?
    }

    let level: DominoLogic.Level
    var board: Board
    /// The board before each of your moves, oldest first, for undo.
    var history: [Board] = []

    var over: Bool { board.you.isEmpty || board.computer.isEmpty || board.passes >= 2 }
    var result: Result? {
        guard over else { return nil }
        if board.you.isEmpty { return .won }
        if board.computer.isEmpty { return .lost }
        let (you, them) = (board.you.map(\.pips).reduce(0, +), board.computer.map(\.pips).reduce(0, +))
        return you < them ? .won : you > them ? .lost : .tie
    }
    /// Finishing always pays 1; a win or tie pays Easy 2, Hard 3. Undo and hints never cost a star.
    var stars: Int { result == .lost ? 1 : level == .easy ? 2 : 3 }

    /// The open ends, or nil on an empty table.
    var ends: (left: Int, right: Int)? { board.line.first.map { ($0.a, board.line.last!.b) } }

    /// Where a tile can go. On an empty table, anywhere (called right).
    func sides(_ d: Domino) -> [Side] {
        guard let (l, r) = ends else { return [.right] }
        let left = d.a == l || d.b == l, right = d.a == r || d.b == r
        if left, right, l == r { return [.right] }  // both ends the same number: one place to play
        return (left ? [Side.left] : []) + (right ? [.right] : [])
    }

    /// Indexes of your tiles that fit, or none when you must draw or pass.
    var playable: [Int] { board.you.indices.filter { !sides(board.you[$0]).isEmpty } }
    var mustDraw: Bool { !over && playable.isEmpty && !board.pile.isEmpty }
    var mustPass: Bool { !over && playable.isEmpty && board.pile.isEmpty }

    /// Plays your tile on a side, then the computer takes its turn.
    mutating func play(_ i: Int, on side: Side) -> Bool {
        guard !over, board.you.indices.contains(i), sides(board.you[i]).contains(side) else { return false }
        history.append(board)
        Self.place(board.you.remove(at: i), on: side, in: &board)
        board.passes = 0
        computerTurn()
        return true
    }

    /// Takes one tile from the pile; only when nothing in your hand fits.
    mutating func draw() -> Bool {
        guard mustDraw else { return false }
        history.append(board)
        board.you.append(board.pile.removeFirst())
        board.said = nil
        return true
    }

    /// Skips your turn; only when nothing fits and the pile is empty.
    mutating func pass() -> Bool {
        guard mustPass else { return false }
        history.append(board)
        board.passes += 1
        computerTurn()
        return true
    }

    mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        board = last
        return true
    }

    /// A tile of yours that fits, for Hint.
    var hint: Int? { playable.max { board.you[$0].pips < board.you[$1].pips } }

    /// The computer draws until a tile fits, then plays it; with nothing to play and no pile, it passes.
    private mutating func computerTurn() {
        guard !over else { board.said = nil; return }
        var drew = 0
        while true {
            let moves = board.computer.indices.flatMap { i in sides(board.computer[i]).map { (i, $0) } }
            let move = level == .easy ? moves.first : moves.max { board.computer[$0.0].pips < board.computer[$1.0].pips }
            let took = drew == 0 ? "" : "drew \(drew) \(drew == 1 ? "tile" : "tiles") and "
            if let (i, side) = move {
                let d = board.computer.remove(at: i)
                Self.place(d, on: side, in: &board)
                board.passes = 0
                board.said = "The computer \(took)played the \(d.name) on the \(side.rawValue)."
                return
            }
            if board.pile.isEmpty {
                board.passes += 1
                board.said = "The computer \(took)couldn't play, so it passed."
                return
            }
            board.computer.append(board.pile.removeFirst())
            drew += 1
        }
    }

    /// Turns the tile so its matching number touches the end.
    private static func place(_ d: Domino, on side: Side, in board: inout Board) {
        guard let first = board.line.first, let last = board.line.last else { board.line = [d]; return }
        switch side {
        case .left: board.line.insert(d.b == first.a ? d : d.flipped, at: 0); board.left += 1
        case .right: board.line.append(d.a == last.b ? d : d.flipped)
        }
    }
}

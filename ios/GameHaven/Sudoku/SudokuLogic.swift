import Foundation

/// Sudoku rules: generate puzzles with exactly one solution, and count solutions.
/// A grid is 81 ints in row order, 0 for an empty square.
nonisolated enum SudokuLogic {
    enum Level: String, CaseIterable, Codable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        var clues: Int {
            switch self {
            case .easy: 40
            case .medium: 32
            case .hard: 26
            }
        }
    }

    /// For each square, the 20 squares that share its row, column or box.
    static let peers: [[Int]] = (0..<81).map { i in
        (0..<81).filter { j in
            j != i && (i / 9 == j / 9 || i % 9 == j % 9 || (i / 27 == j / 27 && i % 9 / 3 == j % 9 / 3))
        }
    }

    /// Every row, column and box, as square lists.
    static let units: [[Int]] = (0..<9).flatMap { (k: Int) -> [[Int]] in
        let row: [Int] = (0..<9).map { k * 9 + $0 }
        let col: [Int] = (0..<9).map { $0 * 9 + k }
        let box: [Int] = (0..<9).map { (k / 3 * 3 + $0 / 3) * 9 + k % 3 * 3 + $0 % 3 }
        return [row, col, box]
    }

    /// A puzzle that fits its level: Easy and Medium fall to the two simplest steps alone, Hard needs more.
    /// Tries the following seeds in turn, so a seed still always gives the same puzzle.
    static func generate(_ level: Level, seed: UInt64) -> (puzzle: [Int], solution: [Int]) {
        var s = seed
        while true {
            let g = generate(clues: level.clues, seed: s)
            if solvesBySingles(g.puzzle) == (level != .hard) { return g }
            s &+= 1
        }
    }

    /// Whether the puzzle can be finished by only ever filling a square with one possible number,
    /// or a number with one possible square in its row, column or box.
    static func solvesBySingles(_ puzzle: [Int]) -> Bool {
        var g = puzzle
        var moved = true
        while moved {
            moved = false
            for i in 0..<81 where g[i] == 0 {
                let mask = candidates(g, i)
                if mask.nonzeroBitCount == 1 { g[i] = mask.trailingZeroBitCount; moved = true }
            }
            for u in units {
                for d in 1...9 where !u.contains(where: { g[$0] == d }) {
                    let spots = u.filter { g[$0] == 0 && candidates(g, $0) & (1 << d) != 0 }
                    if spots.count == 1 { g[spots[0]] = d; moved = true }
                }
            }
        }
        return !g.contains(0)
    }

    /// Hard may keep a few extra clues when no more can go without losing uniqueness.
    static func generate(clues: Int, seed: UInt64) -> (puzzle: [Int], solution: [Int]) {
        var rng = SplitMix64(seed: seed)
        var solution = [Int](repeating: 0, count: 81)
        _ = fill(&solution, &rng)
        var puzzle = solution
        var filled = 81
        for i in (0..<81).shuffled(using: &rng) {
            if filled <= clues { break }
            let keep = puzzle[i]
            puzzle[i] = 0
            if countSolutions(&puzzle) == 1 {
                filled -= 1
            } else {
                puzzle[i] = keep
            }
        }
        return (puzzle, solution)
    }

    /// Counts solutions up to limit. Leaves g unchanged.
    static func countSolutions(_ g: inout [Int], limit: Int = 2) -> Int {
        guard let (i, mask) = bestCell(g) else { return 1 }
        var n = 0
        for d in 1...9 where mask & (1 << d) != 0 {
            g[i] = d
            n += countSolutions(&g, limit: limit - n)
            if n >= limit { break }
        }
        g[i] = 0
        return n
    }

    /// Bit d is set when digit d (1-9) can go in square i.
    static func candidates(_ g: [Int], _ i: Int) -> Int {
        var used = 0
        for p in peers[i] { used |= 1 << g[p] }
        return ~used & 0x3FE
    }

    private static func fill(_ g: inout [Int], _ rng: inout SplitMix64) -> Bool {
        guard let (i, mask) = bestCell(g) else { return true }
        for d in (1...9).shuffled(using: &rng) where mask & (1 << d) != 0 {
            g[i] = d
            if fill(&g, &rng) { return true }
        }
        g[i] = 0
        return false
    }

    /// The empty square with the fewest candidates; nil when the grid is full.
    /// Trying the tightest square first keeps the search fast.
    private static func bestCell(_ g: [Int]) -> (Int, Int)? {
        var best: (Int, Int)?
        var bestN = 10
        for i in 0..<81 where g[i] == 0 {
            let mask = candidates(g, i)
            let n = mask.nonzeroBitCount
            if n < bestN {
                best = (i, mask)
                bestN = n
                if n <= 1 { break }
            }
        }
        return best
    }
}

/// One saved Sudoku game.
/// history holds one entry per move, for unlimited undo: [square, previous digit]. Older saves may carry extra fields, which undo ignores.
nonisolated struct SudokuGame: Codable {
    var puzzle: [Int]
    var solution: [Int]
    var board: [Int]
    var history: [[Int]] = []
    var level: SudokuLogic.Level
    /// The day's key (e.g. "2026-11-17") when this is that day's puzzle.
    var daily: String?
    /// Wrong numbers put in, even if later undone. Optional so saves from before it existed still load.
    var mistakes: Int?

    var solved: Bool { board == solution }

    /// How many more of digit d can go on the board.
    func left(_ d: Int) -> Int { max(0, 9 - board.filter { $0 == d }.count) }

    /// Puts d in square i (0 erases). Given squares can't change.
    mutating func place(_ d: Int, at i: Int) {
        guard puzzle[i] == 0, board[i] != d else { return }
        history.append([i, board[i]])
        board[i] = d
        if d != 0, d != solution[i] { mistakes = (mistakes ?? 0) + 1 }
    }

    /// Easy 1, medium 2, hard 3, plus 1 for no wrong numbers. Hints don't count against it; nothing is ever taken away.
    var stars: Int { SudokuLogic.Level.allCases.firstIndex(of: level)! + 1 + ((mistakes ?? 0) == 0 ? 1 : 0) }

    /// Takes back the last move; returns its square.
    mutating func undo() -> Int? {
        guard let h = history.popLast() else { return nil }
        board[h[0]] = h[1]
        return h[0]
    }

    /// The squares of every row, column and box through square i that are now all correct.
    func finishedUnits(at i: Int) -> Set<Int> {
        let units = [(0..<81).filter { $0 / 9 == i / 9 },
                     (0..<81).filter { $0 % 9 == i % 9 },
                     (0..<81).filter { $0 / 27 == i / 27 && $0 % 9 / 3 == i % 9 / 3 }]
        return Set(units.filter { $0.allSatisfy { board[$0] == solution[$0] } }.joined())
    }
}

/// One shared puzzle a day, the same for every player.
nonisolated enum SudokuDaily {
    static let level = SudokuLogic.Level.medium

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func seed(_ key: String) -> UInt64 { UInt64(key.filter(\.isNumber))! }

    /// Days whose puzzle was solved, by key.
    static var done: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "sudokuDailyDone") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "sudokuDailyDone") }
    }
}

/// Seeded random numbers, so a seed always gives the same puzzle (Swift's default generator can't be seeded).
nonisolated struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

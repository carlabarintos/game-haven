import Foundation

/// Nonogram rules: a hidden picture of filled squares, with clues counting the runs of filled squares in each row and column.
/// A picture is size×size Bools in row order, true for filled.
nonisolated enum NonogramLogic {
    enum Level: String, CaseIterable, Codable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        var size: Int {
            switch self {
            case .easy: 5
            case .medium: 8
            case .hard: 10
            }
        }
    }

    /// The guided first puzzle, a little house, and the line to work on at each step. Lines count rows 0-4, then columns 5-9.
    static let lesson = (picture: "..#...###.#####.#.#..###.".map { $0 == "#" }, lines: [2, 7, 6, 8])

    /// Runs of filled squares along one line, e.g. [2, 1]; [] for a blank line.
    static func clue(_ line: [Bool]) -> [Int] { line.split(separator: false).map(\.count) }

    /// Every row, then every column, as square lists.
    static func lines(_ n: Int) -> [[Int]] {
        (0..<n).map { r in (0..<n).map { r * n + $0 } } + (0..<n).map { c in (0..<n).map { $0 * n + c } }
    }

    /// A mirror-symmetric picture, so it reads like a little emblem rather than noise, that the clues pin down line by line.
    /// Tries fresh pictures from the same generator, so a seed always gives the same puzzle.
    static func generate(_ level: Level, seed: UInt64) -> [Bool] {
        var rng = SplitMix64(seed: seed)
        let n = level.size
        while true {
            var g = [Bool](repeating: false, count: n * n)
            for r in 0..<n {
                for c in 0..<(n + 1) / 2 {
                    let on = Double.random(in: 0..<1, using: &rng) < 0.6
                    g[r * n + c] = on
                    g[r * n + n - 1 - c] = on
                }
            }
            if solvesLineByLine(g, size: n) { return g }
        }
    }

    /// Whether the clues alone, one line at a time, settle every square. Then the picture is the only answer and needs no guessing.
    static func solvesLineByLine(_ picture: [Bool], size n: Int) -> Bool {
        let lines = lines(n)
        var options = lines.map { placements(clue($0.map { picture[$0] }), n) }
        var known = [Bool?](repeating: nil, count: n * n)
        var moved = true
        while moved {
            moved = false
            for (k, line) in lines.enumerated() {
                options[k].removeAll { p in line.indices.contains { i in known[line[i]].map { $0 != p[i] } ?? false } }
                for (i, sq) in line.enumerated() where known[sq] == nil {
                    let v = options[k][0][i]
                    if options[k].allSatisfy({ $0[i] == v }) { known[sq] = v; moved = true }
                }
            }
        }
        return !known.contains(nil)
    }

    /// Every way to lay the runs along a line of length n, with at least one gap between runs.
    static func placements(_ clue: [Int], _ n: Int) -> [[Bool]] {
        guard let first = clue.first else { return [[Bool](repeating: false, count: n)] }
        let rest = Array(clue.dropFirst())
        let restMin = rest.reduce(0, +) + rest.count
        guard first + restMin <= n else { return [] }
        return (0...(n - first - restMin)).flatMap { start -> [[Bool]] in
            let head = [Bool](repeating: false, count: start) + [Bool](repeating: true, count: first)
            if rest.isEmpty { return [head + [Bool](repeating: false, count: n - head.count)] }
            return placements(rest, n - head.count - 1).map { head + [false] + $0 }
        }
    }
}

/// One saved nonogram. A wrong guess is put right on the spot and remembered, so the board never holds a mistake but still shows where one was.
nonisolated struct NonogramGame: Codable {
    enum Mark: Int, Codable { case blank, fill, cross }

    var solution: [Bool]
    var marks: [Mark]
    var level: NonogramLogic.Level
    /// Squares a wrong guess went in, shown red.
    var wrong: Set<Int> = []
    var mistakes: Int { wrong.count }

    init(solution: [Bool], level: NonogramLogic.Level) {
        self.solution = solution
        self.level = level
        marks = .init(repeating: .blank, count: solution.count)
        for line in NonogramLogic.lines(level.size) where done(line) {  // blank lines start crossed off
            for j in line { marks[j] = .cross }
        }
    }

    var size: Int { level.size }
    var solved: Bool { zip(solution, marks).allSatisfy { !$0 || $1 == .fill } }

    /// Easy 1, medium 2, hard 3, plus 1 for no wrong guesses. Hints don't count against it.
    var stars: Int { NonogramLogic.Level.allCases.firstIndex(of: level)! + 1 + (mistakes == 0 ? 1 : 0) }

    func clue(_ line: [Int]) -> [Int] { NonogramLogic.clue(line.map { solution[$0] }) }

    /// Whether every filled square of the line has been found.
    func done(_ line: [Int]) -> Bool { line.allSatisfy { !solution[$0] || marks[$0] == .fill } }

    /// Fills or crosses blank square i; returns whether the guess was right.
    /// A row or column it finishes has its other blanks crossed off.
    @discardableResult mutating func mark(_ i: Int, fill: Bool) -> Bool {
        guard marks[i] == .blank else { return true }
        marks[i] = solution[i] ? .fill : .cross
        if fill != solution[i] { wrong.insert(i) }
        for line in NonogramLogic.lines(size) where line.contains(i) && done(line) {
            for j in line where marks[j] == .blank { marks[j] = .cross }
        }
        return fill == solution[i]
    }

    /// The squares of every row and column through square i that are now finished.
    func finishedLines(at i: Int) -> Set<Int> {
        Set(NonogramLogic.lines(size).filter { $0.contains(i) && done($0) }.joined())
    }
}

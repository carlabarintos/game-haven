import Foundation

/// Word search rules: hide a theme's words in a square of letters, and check the player's picks.
/// Squares are numbered in row order, 0 at the top left.
nonisolated enum WordSearchLogic {
    enum Level: String, CaseIterable, Codable {
        case easy = "Easy", medium = "Medium", hard = "Hard"
        var size: Int {
            switch self {
            case .easy: 7
            case .medium: 9
            case .hard: 11
            }
        }
        var words: Int {
            switch self {
            case .easy: 6
            case .medium: 8
            case .hard: 10
            }
        }
        /// Steps as (row, column). Easy reads across and down only, Medium adds diagonals, Hard adds backwards.
        var directions: [(Int, Int)] {
            let forward = [(0, 1), (1, 0)]
            let diagonal = [(1, 1), (-1, 1)]
            switch self {
            case .easy: return forward
            case .medium: return forward + diagonal
            case .hard: return (forward + diagonal).flatMap { [$0, (-$0.0, -$0.1)] }
            }
        }
    }

    /// No word in a theme sits inside another, so finding one never half-finds another.
    static let themes: [(name: String, words: [String])] = [
        ("In the Garden", ["ROSE", "TULIP", "DAISY", "FERN", "MOSS", "SEED", "SOIL", "HOSE", "RAKE", "SPADE", "PANSY", "LILY", "POPPY", "VIOLET", "ORCHID", "BLOSSOM", "SUNFLOWER", "LAVENDER"]),
        ("The Kitchen", ["BREAD", "SCONE", "TEAPOT", "KETTLE", "SPOON", "FORK", "BOWL", "OVEN", "APRON", "FLOUR", "BUTTER", "HONEY", "JAM", "TOAST", "MUFFIN", "PANCAKE", "SAUCER"]),
        ("By the Sea", ["SHELL", "SAND", "WAVE", "TIDE", "CRAB", "GULL", "PIER", "BOAT", "SURF", "KELP", "DUNE", "OCEAN", "ANCHOR", "LIGHTHOUSE", "STARFISH", "PEBBLE"]),
        ("Birds", ["ROBIN", "WREN", "OWL", "CROW", "DOVE", "HERON", "SWAN", "DUCK", "FINCH", "EAGLE", "MAGPIE", "PARROT", "PELICAN", "SPARROW", "KOOKABURRA", "CANARY"]),
        ("Weather", ["RAIN", "SNOW", "WIND", "HAIL", "MIST", "FOG", "CLOUD", "STORM", "SUNNY", "FROST", "BREEZE", "THUNDER", "DRIZZLE", "SUNSHINE", "HUMID"]),
        ("Holidays", ["TRAIN", "PLANE", "MAP", "BUS", "SHIP", "HOTEL", "BEACH", "TICKET", "SUITCASE", "PASSPORT", "CAMERA", "POSTCARD", "CRUISE", "TOUR", "ROAD"]),
    ]

    /// A full puzzle for the level. Tries the following seeds in turn until every word fits, so a seed always gives the same puzzle.
    static func generate(_ level: Level, seed: UInt64) -> WordSearchGame {
        var s = seed
        while true {
            if let g = attempt(level, seed: s) { return g }
            s &+= 1
        }
    }

    private static func attempt(_ level: Level, seed: UInt64) -> WordSearchGame? {
        var rng = SplitMix64(seed: seed)
        let n = level.size
        let theme = themes.randomElement(using: &rng)!
        var grid = [Character?](repeating: nil, count: n * n)
        var placed: [WordSearchGame.Find] = []
        for word in theme.words.filter({ $0.count <= n }).shuffled(using: &rng) where placed.count < level.words {
            let letters = Array(word)
            for _ in 0..<100 {
                let (dr, dc) = level.directions.randomElement(using: &rng)!
                let r = Int.random(in: 0..<n, using: &rng), c = Int.random(in: 0..<n, using: &rng)
                let er = r + dr * (letters.count - 1), ec = c + dc * (letters.count - 1)
                guard (0..<n).contains(er), (0..<n).contains(ec) else { continue }
                let squares = (0..<letters.count).map { (r + dr * $0) * n + c + dc * $0 }
                guard zip(squares, letters).allSatisfy({ grid[$0] == nil || grid[$0] == $1 }) else { continue }
                for (i, ch) in zip(squares, letters) { grid[i] = ch }
                placed.append(.init(word: word, start: squares.first!, end: squares.last!))
                break
            }
        }
        guard placed.count == level.words else { return nil }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let letters = grid.map { String($0 ?? alphabet.randomElement(using: &rng)!) }
        return WordSearchGame(size: n, letters: letters, theme: theme.name, level: level, hidden: placed.sorted { $0.word < $1.word })
    }
}

/// One saved word search.
nonisolated struct WordSearchGame: Codable {
    struct Find: Codable, Equatable {
        let word: String
        let start: Int
        let end: Int
    }

    let size: Int
    /// One capital letter per square.
    let letters: [String]
    let theme: String
    let level: WordSearchLogic.Level
    /// Where each word was hidden, in the order the list shows them.
    let hidden: [Find]
    /// Words found so far, with the squares the player picked.
    var found: [Find] = []

    var words: [String] { hidden.map(\.word) }
    var solved: Bool { found.count == hidden.count }
    func isFound(_ word: String) -> Bool { found.contains { $0.word == word } }

    /// Easy 1, medium 2, hard 3. Hints never cost a star.
    var stars: Int { WordSearchLogic.Level.allCases.firstIndex(of: level)! + 1 }

    /// The squares from a to b, or nil if they aren't on one straight line across, down or diagonal.
    func line(_ a: Int, _ b: Int) -> [Int]? {
        let dr = b / size - a / size, dc = b % size - a % size
        guard a != b, dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return nil }
        let steps = max(abs(dr), abs(dc))
        return (0...steps).map { a + ($0 * dr / steps) * size + $0 * dc / steps }
    }

    /// Where a slide from square a ends, its finger `across` and `down` squares away: the nearest of the eight
    /// straight lines, stopped at the edge, so a wobbly finger still picks a clean line.
    func snap(from a: Int, across: Double, down: Double) -> Int {
        let angle = (atan2(down, across) / (.pi / 4)).rounded() * .pi / 4
        let dr = Int(sin(angle).rounded()), dc = Int(cos(angle).rounded())
        var steps = Int(max(abs(across), abs(down)).rounded())
        while steps > 0, !(0..<size).contains(a / size + dr * steps) || !(0..<size).contains(a % size + dc * steps) { steps -= 1 }
        return a + dr * steps * size + dc * steps
    }

    /// Marks the word spelled from a to b, read either way, if it's on the list and not found yet. Returns it.
    mutating func pick(_ a: Int, _ b: Int) -> String? {
        guard let squares = line(a, b) else { return nil }
        let spelled = squares.map { letters[$0] }.joined()
        guard let word = words.first(where: { ($0 == spelled || $0 == String(spelled.reversed())) && !isFound($0) }) else { return nil }
        found.append(.init(word: word, start: a, end: b))
        return word
    }
}
